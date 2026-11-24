import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:geomag/database/app_database.dart';

/// Service untuk memformat dan mengekspor data sampel mentah ke file CSV.
class CsvExportService {
  /// Header standar CSV data sampel magnetometer mentah.
  static const String csvHeader =
      'timestamp_ns,raw_x_micro_t,raw_y_micro_t,raw_z_micro_t,'
      'bias_x_micro_t,bias_y_micro_t,bias_z_micro_t,'
      'accuracy,is_uncalibrated,battery_temp_c,is_charging,is_screen_on';

  /// Mengonversi list [Sample] dari database ke format CSV String.
  String generateCsvString(List<Sample> samples) {
    final buffer = StringBuffer();
    buffer.writeln(csvHeader);

    for (final s in samples) {
      buffer.writeln(
        '${s.timestampNs},'
        '${s.rawXMicroT},'
        '${s.rawYMicroT},'
        '${s.rawZMicroT},'
        '${s.biasXMicroT},'
        '${s.biasYMicroT},'
        '${s.biasZMicroT},'
        '${s.accuracy},'
        '${s.isUncalibrated},'
        '${s.batteryTempC},'
        '${s.isCharging},'
        '${s.isScreenOn}',
      );
    }

    return buffer.toString();
  }

  /// Menulis data sampel ke file CSV di direktori tujuan.
  ///
  /// Mengembalikan [File] yang berhasil ditulis.
  Future<File> exportStationSamplesToCsv({
    required String stationId,
    required List<Sample> samples,
    required Directory outputDirectory,
    String? customFileName,
  }) async {
    if (!await outputDirectory.exists()) {
      await outputDirectory.create(recursive: true);
    }

    final timestampStr = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = customFileName ?? 'geomag_station_${stationId}_$timestampStr.csv';
    final filePath = p.join(outputDirectory.path, fileName);
    final file = File(filePath);

    final csvContent = generateCsvString(samples);
    await file.writeAsString(csvContent, flush: true);

    return file;
  }
}
