"""Modul referensi Python untuk ekspor data geomagnetik ke format GIS (QGIS, ArcGIS).

Mendukung:
1. ESRI ASCII Grid (.asc) untuk raster grid (Total Field, Delta T, Analytic Signal)
2. GeoJSON FeatureCollection WGS-84 untuk titik-titik stasiun survei
3. CSV komprehensif mengintegrasikan data observasi, koreksi harian, IGRF, dan anomali.
"""

from __future__ import annotations
import json
from typing import Any, Dict, List, Optional, Sequence


def export_esri_ascii_grid(
    values: Sequence[Sequence[Optional[float]]],
    xllcorner: float,
    yllcorner: float,
    cellsize: float,
    nodata_value: float = -9999.0,
) -> str:
    """Mengekspor matriks 2D ke format ESRI ASCII Grid (.asc).

    Perhatian standar ESRI ASCII Grid:
    - Baris pertama di file adalah baris paling UTARA (Y maksimum).
    - Asumsi input: values[j][i] di mana j=0 adalah baris Y minimum (yllcorner),
      dan j=(nrows-1) adalah baris Y maksimum.
    - Oleh karena itu, baris ditulis dari indeks j=(nrows-1) turun ke j=0.
    """
    nrows = len(values)
    if nrows == 0:
        ncols = 0
    else:
        ncols = len(values[0])

    lines = [
        f"ncols         {ncols}",
        f"nrows         {nrows}",
        f"xllcorner     {xllcorner:.6f}",
        f"yllcorner     {yllcorner:.6f}",
        f"cellsize      {cellsize:.6f}",
        f"NODATA_value  {int(nodata_value) if nodata_value.is_integer() else nodata_value}",
    ]

    # Tulis dari baris paling atas (Y terbesar) ke baris paling bawah (Y terkecil)
    for j in range(nrows - 1, -1, -1):
        row_vals: List[str] = []
        for i in range(ncols):
            val = values[j][i]
            if val is None:
                row_vals.append(f"{nodata_value:.1f}")
            else:
                row_vals.append(f"{val:.3f}")
        lines.append(" ".join(row_vals))

    return "\n".join(lines) + "\n"


def export_stations_geojson(stations: Sequence[Dict[str, Any]]) -> str:
    """Mengekspor daftar data stasiun ke string GeoJSON FeatureCollection standar WGS-84."""
    features = []
    for st in stations:
        lon = st.get("longitude")
        lat = st.get("latitude")
        if lon is None or lat is None:
            continue

        feature = {
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [float(lon), float(lat)],
            },
            "properties": {
                "station_id": str(st.get("station_id", "")),
                "sequence_number": int(st.get("sequence_number", 0)),
                "x_m": float(st.get("x_m", 0.0)),
                "y_m": float(st.get("y_m", 0.0)),
                "total_field_nt": round(float(st.get("total_field_nt", 0.0)), 2),
                "diurnal_correction_nt": (
                    round(float(st["diurnal_correction_nt"]), 2)
                    if st.get("diurnal_correction_nt") is not None
                    else None
                ),
                "f_igrf_nt": (
                    round(float(st["f_igrf_nt"]), 2)
                    if st.get("f_igrf_nt") is not None
                    else None
                ),
                "delta_t_nt": (
                    round(float(st["delta_t_nt"]), 2)
                    if st.get("delta_t_nt") is not None
                    else None
                ),
                "quality_flag": str(st.get("quality_flag", "ACCEPTED")),
                "operator_note": st.get("operator_note"),
            },
        }
        features.append(feature)

    geojson_obj = {
        "type": "FeatureCollection",
        "name": "geomag_stations",
        "crs": {
            "type": "name",
            "properties": {"name": "urn:ogc:def:crs:OGC:1.3:CRS84"},
        },
        "features": features,
    }

    return json.dumps(geojson_obj, indent=2)


def export_anomalies_csv(records: Sequence[Dict[str, Any]]) -> str:
    """Mengekspor data gabungan stasiun dan anomali ke format CSV standar."""
    headers = [
        "station_id",
        "sequence_number",
        "latitude",
        "longitude",
        "local_x_m",
        "local_y_m",
        "total_field_mean_nt",
        "total_field_std_nt",
        "sample_count",
        "diurnal_correction_nt",
        "f_igrf_nt",
        "delta_t_nt",
        "quality_flag",
        "operator_note",
    ]

    lines = [",".join(headers)]
    for r in records:
        row = [
            str(r.get("station_id", "")),
            str(r.get("sequence_number", "")),
            f"{r['latitude']:.7f}" if r.get("latitude") is not None else "",
            f"{r['longitude']:.7f}" if r.get("longitude") is not None else "",
            f"{r['local_x_m']:.2f}" if r.get("local_x_m") is not None else "",
            f"{r['local_y_m']:.2f}" if r.get("local_y_m") is not None else "",
            f"{r['total_field_mean_nt']:.2f}" if r.get("total_field_mean_nt") is not None else "",
            f"{r['total_field_std_nt']:.2f}" if r.get("total_field_std_nt") is not None else "",
            str(r.get("sample_count", "")),
            f"{r['diurnal_correction_nt']:.2f}" if r.get("diurnal_correction_nt") is not None else "",
            f"{r['f_igrf_nt']:.2f}" if r.get("f_igrf_nt") is not None else "",
            f"{r['delta_t_nt']:.2f}" if r.get("delta_t_nt") is not None else "",
            str(r.get("quality_flag", "ACCEPTED")),
            f'"{r.get("operator_note", "")}"' if r.get("operator_note") else "",
        ]
        lines.append(",".join(row))

    return "\n".join(lines) + "\n"
