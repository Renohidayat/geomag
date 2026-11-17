import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/services/csv_export_service.dart';

void main() {
  group('CsvExportService', () {
    late CsvExportService service;
    late Directory tempDir;

    setUp(() async {
      service = CsvExportService();
      tempDir = await Directory.systemTemp.createTemp('geomag_csv_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generateCsvString menghasilkan header dan baris data yang tepat', () {
      final samples = [
        Sample(
          id: 's-1',
          stationId: 'stn-01',
          calibrationId: null,
          timestampNs: BigInt.from(1234567890123),
          rawXMicroT: 25.12,
          rawYMicroT: -10.45,
          rawZMicroT: 42.88,
          biasXMicroT: 0.1,
          biasYMicroT: -0.2,
          biasZMicroT: 0.3,
          accuracy: 3,
          isUncalibrated: true,
          batteryTempC: 32.5,
          isCharging: false,
          isScreenOn: true,
          recordedAt: DateTime.now(),
        ),
      ];

      final csv = service.generateCsvString(samples);
      final lines = csv.trim().split('\n');

      expect(lines.length, 2);
      expect(
        lines[0].trim(),
        'timestamp_ns,raw_x_micro_t,raw_y_micro_t,raw_z_micro_t,'
        'bias_x_micro_t,bias_y_micro_t,bias_z_micro_t,'
        'accuracy,is_uncalibrated,battery_temp_c,is_charging,is_screen_on',
      );
      expect(
        lines[1].trim(),
        '1234567890123,25.12,-10.45,42.88,0.1,-0.2,0.3,3,true,32.5,false,true',
      );
    });

    test('exportStationSamplesToCsv menulis file CSV fisik dengan benar', () async {
      final samples = [
        Sample(
          id: 's-1',
          stationId: 'stn-test',
          calibrationId: null,
          timestampNs: BigInt.from(1000000),
          rawXMicroT: 1.0,
          rawYMicroT: 2.0,
          rawZMicroT: 3.0,
          biasXMicroT: 0.0,
          biasYMicroT: 0.0,
          biasZMicroT: 0.0,
          accuracy: 3,
          isUncalibrated: true,
          batteryTempC: 30.0,
          isCharging: false,
          isScreenOn: true,
          recordedAt: DateTime.now(),
        ),
      ];

      final file = await service.exportStationSamplesToCsv(
        stationId: 'stn-test',
        samples: samples,
        outputDirectory: tempDir,
        customFileName: 'test_export.csv',
      );

      expect(await file.exists(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('timestamp_ns,raw_x_micro_t'));
      expect(content, contains('1000000,1.0,2.0,3.0'));
    });
  });
}
