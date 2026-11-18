import json
import pytest
from reference.qgis_export import (
    export_esri_ascii_grid,
    export_stations_geojson,
    export_anomalies_csv,
)


def test_export_esri_ascii_grid_format_and_row_order():
    # 2 rows x 3 cols:
    # Row j=0 (Y min): [1.0, 2.0, 3.0]
    # Row j=1 (Y max): [4.0, 5.0, 6.0]
    values = [
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
    ]
    asc_str = export_esri_ascii_grid(
        values=values,
        xllcorner=100.0,
        yllcorner=200.0,
        cellsize=10.0,
        nodata_value=-9999.0,
    )

    lines = [line.strip() for line in asc_str.strip().split("\n")]
    assert len(lines) == 8  # 6 header lines + 2 data lines

    assert lines[0] == "ncols         3"
    assert lines[1] == "nrows         2"
    assert lines[2] == "xllcorner     100.000000"
    assert lines[3] == "yllcorner     200.000000"
    assert lines[4] == "cellsize      10.000000"
    assert lines[5] == "NODATA_value  -9999"

    # Baris data pertama harus baris paling utara (j=1: 4.000 5.000 6.000)
    assert lines[6] == "4.000 5.000 6.000"
    # Baris data kedua adalah j=0: 1.000 2.000 3.000
    assert lines[7] == "1.000 2.000 3.000"


def test_export_esri_ascii_grid_with_none_values():
    values = [
        [None, 12.5],
        [34.2, None],
    ]
    asc_str = export_esri_ascii_grid(
        values=values,
        xllcorner=0.0,
        yllcorner=0.0,
        cellsize=5.0,
        nodata_value=-9999.0,
    )
    lines = [line.strip() for line in asc_str.strip().split("\n")]
    assert lines[6] == "34.200 -9999.0"
    assert lines[7] == "-9999.0 12.500"


def test_export_stations_geojson_valid_json():
    stations = [
        {
            "station_id": "ST-01",
            "sequence_number": 1,
            "latitude": -6.891234,
            "longitude": 107.612345,
            "x_m": 0.0,
            "y_m": 0.0,
            "total_field_nt": 45050.25,
            "diurnal_correction_nt": 4.15,
            "f_igrf_nt": 44980.10,
            "delta_t_nt": 66.00,
            "quality_flag": "ACCEPTED",
        },
        {
            "station_id": "ST-02",
            "sequence_number": 2,
            "latitude": -6.892000,
            "longitude": 107.613000,
            "x_m": 10.0,
            "y_m": 0.0,
            "total_field_nt": 45080.50,
            "quality_flag": "FLAGGED",
            "operator_note": "Dekat pagar kawat",
        },
    ]

    geojson_str = export_stations_geojson(stations)
    parsed = json.loads(geojson_str)

    assert parsed["type"] == "FeatureCollection"
    assert len(parsed["features"]) == 2

    f1 = parsed["features"][0]
    assert f1["type"] == "Feature"
    assert f1["geometry"]["type"] == "Point"
    assert f1["geometry"]["coordinates"] == [107.612345, -6.891234]
    assert f1["properties"]["station_id"] == "ST-01"
    assert f1["properties"]["delta_t_nt"] == 66.00
    assert f1["properties"]["quality_flag"] == "ACCEPTED"

    f2 = parsed["features"][1]
    assert f2["properties"]["operator_note"] == "Dekat pagar kawat"
    assert f2["properties"]["diurnal_correction_nt"] is None


def test_export_anomalies_csv():
    records = [
        {
            "station_id": "ST-01",
            "sequence_number": 1,
            "latitude": -6.891234,
            "longitude": 107.612345,
            "local_x_m": 0.0,
            "local_y_m": 0.0,
            "total_field_mean_nt": 45050.25,
            "total_field_std_nt": 1.25,
            "sample_count": 600,
            "diurnal_correction_nt": 4.15,
            "f_igrf_nt": 44980.10,
            "delta_t_nt": 66.00,
            "quality_flag": "ACCEPTED",
            "operator_note": "Aman",
        }
    ]

    csv_str = export_anomalies_csv(records)
    lines = csv_str.strip().split("\n")
    assert len(lines) == 2
    assert "station_id,sequence_number,latitude,longitude" in lines[0]
    assert "ST-01,1,-6.8912340,107.6123450,0.00,0.00,45050.25,1.25,600,4.15,44980.10,66.00,ACCEPTED,\"Aman\"" in lines[1]
