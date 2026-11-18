import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../screens/anomaly_map_screen.dart';
import 'gridding_service.dart';

/// Layanan untuk mengekspor data geomagnetik (grid raster dan titik vektor stasiun)
/// ke format standar GIS seperti ESRI ASCII Grid (.asc), GeoJSON (.geojson), dan CSV.
class QgisExportService {
  const QgisExportService();

  /// Mengonversi objek [Grid2D] menjadi representasi teks format ESRI ASCII Grid (.asc).
  ///
  /// Format standar ESRI ASCII Grid:
  /// - Header memuat ncols, nrows, xllcorner, yllcorner, cellsize, NODATA_value.
  /// - Baris pertama data di file adalah baris paling UTARA (Y maksimum).
  /// - Oleh karena itu, baris ditulis dari indeks j = nrows - 1 turun ke j = 0.
  String formatEsriAsciiGrid(
    Grid2D grid, {
    double nodataValue = -9999.0,
  }) {
    final buffer = StringBuffer();
    final nodataInt = nodataValue.truncateToDouble() == nodataValue
        ? nodataValue.toInt().toString()
        : nodataValue.toString();

    buffer.writeln('ncols         ${grid.nx}');
    buffer.writeln('nrows         ${grid.ny}');
    buffer.writeln('xllcorner     ${grid.xMin.toStringAsFixed(6)}');
    buffer.writeln('yllcorner     ${grid.yMin.toStringAsFixed(6)}');
    buffer.writeln('cellsize      ${grid.dx.toStringAsFixed(6)}');
    buffer.writeln('NODATA_value  $nodataInt');

    // Tulis dari baris paling atas (Y terbesar) ke baris paling bawah (Y terkecil)
    for (int j = grid.ny - 1; j >= 0; j--) {
      final row = grid.values[j];
      final rowStr = row.map((val) {
        if (val.isNaN || val.isInfinite) {
          return nodataValue.toStringAsFixed(1);
        }
        return val.toStringAsFixed(3);
      }).join(' ');
      buffer.writeln(rowStr);
    }

    return buffer.toString();
  }

  /// Mengonversi daftar [MapStationMarker] menjadi GeoJSON FeatureCollection WGS-84.
  ///
  /// Hanya stasiun yang memiliki koordinat latitude & longitude valid yang disertakan.
  String formatStationsGeoJson(List<MapStationMarker> stations) {
    final features = <Map<String, dynamic>>[];

    for (final st in stations) {
      if (st.latitude == null || st.longitude == null) continue;

      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [st.longitude!, st.latitude!],
        },
        'properties': {
          'station_id': st.stationId,
          'sequence_number': st.sequenceNumber,
          'x_m': double.parse(st.x.toStringAsFixed(2)),
          'y_m': double.parse(st.y.toStringAsFixed(2)),
          'total_field_nt': double.parse(st.totalFieldNt.toStringAsFixed(2)),
          'diurnal_correction_nt': st.diurnalCorrectionNt != null
              ? double.parse(st.diurnalCorrectionNt!.toStringAsFixed(2))
              : null,
          'f_igrf_nt': st.fIgrfNt != null
              ? double.parse(st.fIgrfNt!.toStringAsFixed(2))
              : null,
          'delta_t_nt': st.deltaTNt != null
              ? double.parse(st.deltaTNt!.toStringAsFixed(2))
              : null,
          'is_accepted': st.isAccepted,
          'quality_flag': st.qualityFlag,
        },
      });
    }

    final geoJsonMap = {
      'type': 'FeatureCollection',
      'name': 'geomag_stations',
      'crs': {
        'type': 'name',
        'properties': {'name': 'urn:ogc:def:crs:OGC:1.3:CRS84'},
      },
      'features': features,
    };

    return const JsonEncoder.withIndent('  ').convert(geoJsonMap);
  }

  /// Mengonversi daftar [MapStationMarker] menjadi string CSV komprehensif.
  String formatAnomaliesCsv(List<MapStationMarker> stations) {
    final buffer = StringBuffer();
    buffer.writeln(
      'station_id,sequence_number,latitude,longitude,local_x_m,local_y_m,'
      'total_field_nt,diurnal_correction_nt,f_igrf_nt,delta_t_nt,is_accepted,quality_flag',
    );

    for (final st in stations) {
      final latStr = st.latitude?.toStringAsFixed(7) ?? '';
      final lonStr = st.longitude?.toStringAsFixed(7) ?? '';
      final xStr = st.x.toStringAsFixed(2);
      final yStr = st.y.toStringAsFixed(2);
      final tfStr = st.totalFieldNt.toStringAsFixed(2);
      final diurnalStr = st.diurnalCorrectionNt?.toStringAsFixed(2) ?? '';
      final igrfStr = st.fIgrfNt?.toStringAsFixed(2) ?? '';
      final dtStr = st.deltaTNt?.toStringAsFixed(2) ?? '';

      buffer.writeln(
        '${st.stationId},${st.sequenceNumber},$latStr,$lonStr,$xStr,$yStr,'
        '$tfStr,$diurnalStr,$igrfStr,$dtStr,${st.isAccepted},${st.qualityFlag}',
      );
    }

    return buffer.toString();
  }

  /// Menyimpan teks raster ESRI ASCII Grid ke file.
  Future<File> exportAsciiGridToFile({
    required Grid2D grid,
    required String filePath,
    double nodataValue = -9999.0,
  }) async {
    final content = formatEsriAsciiGrid(grid, nodataValue: nodataValue);
    final file = File(filePath);
    return file.writeAsString(content);
  }

  /// Menyimpan representasi GeoJSON titik stasiun ke file.
  Future<File> exportGeoJsonToFile({
    required List<MapStationMarker> stations,
    required String filePath,
  }) async {
    final content = formatStationsGeoJson(stations);
    final file = File(filePath);
    return file.writeAsString(content);
  }

  /// Menyimpan data CSV anomali terintegrasi ke file.
  Future<File> exportCsvToFile({
    required List<MapStationMarker> stations,
    required String filePath,
  }) async {
    final content = formatAnomaliesCsv(stations);
    final file = File(filePath);
    return file.writeAsString(content);
  }

  /// Mengambil direktori ekspor default aplikasi.
  Future<Directory> getDefaultExportDirectory() async {
    return getApplicationDocumentsDirectory();
  }
}
