import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/sensor_info.dart';
import 'package:geomag/services/base_station_service.dart';
import 'package:geomag/services/magnetometer_service.dart';

class MockBaseMagService extends MagnetometerService {
  final _controller = StreamController<MagnetometerSample>.broadcast();

  @override
  Stream<MagnetometerSample> get sampleStream => _controller.stream;

  @override
  Future<SensorInfo> getSensorInfo() async => const SensorInfo(
        available: true,
        isUncalibrated: true,
        name: 'Mock Base Magnetometer',
      );

  void emitSamples(int count, double baseMicroT, double driftStep) {
    for (var i = 0; i < count; i++) {
      _controller.add(
        MagnetometerSample(
          timestampNs: 1000000000 + i * 20000000,
          rawXMicroT: baseMicroT + (i * driftStep),
          rawYMicroT: 0.0,
          rawZMicroT: 0.0,
          biasXMicroT: 0.0,
          biasYMicroT: 0.0,
          biasZMicroT: 0.0,
          accuracy: 3,
          isUncalibrated: true,
          batteryTempC: 30.0,
          isCharging: false,
          isScreenOn: true,
        ),
      );
    }
  }

  void close() {
    _controller.close();
  }
}

void main() {
  group('BaseStationService', () {
    late AppDatabase db;
    late MockBaseMagService mockMag;
    late BaseStationService service;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      mockMag = MockBaseMagService();
      service = BaseStationService(
        database: db,
        magnetometerService: mockMag,
        batchBufferSize: 10,
      );

      // Inisialisasi Device & Survey
      await db.insertDevice(
        DevicesCompanion.insert(
          id: 'dev_base',
          model: 'Base Station Phone',
          androidVersion: '14',
          magnetometerChip: 'AK09918',
        ),
      );

      await db.insertSurvey(
        SurveysCompanion.insert(
          id: 'surv_base_1',
          deviceId: 'dev_base',
          name: 'Base Survey 1',
          date: DateTime.now(),
          mode: 'base',
        ),
      );

      await db.insertStation(
        StationsCompanion.insert(
          id: 'st_base_1',
          surveyId: 'surv_base_1',
          sequenceNumber: 1,
        ),
      );
    });

    tearDown(() async {
      mockMag.close();
      await db.close();
    });

    test('startBaseRecording mengumpulkan sampel, membuat drift points, dan flush buffer', () async {
      await service.startBaseRecording(
        surveyId: 'surv_base_1',
        stationId: 'st_base_1',
      );

      expect(service.isRecording, isTrue);

      // Pancarkan 25 sampel (akan flush 2 batch @ 10 sampel)
      mockMag.emitSamples(25, 45.0, 0.02);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(service.totalRecordedCount, equals(25));
      expect(service.baselineFieldNt, closeTo(45000.0, 10.0));
      expect(service.driftPoints, isNotEmpty);
      expect(service.driftRangeNt, greaterThan(0.0));

      // Hentikan perekaman
      await service.stopBaseRecording();
      expect(service.isRecording, isFalse);

      // Verifikasi seluruh 25 sampel tersimpan di SQLite Drift (zero data loss)
      final samplesInDb = await db.getSamplesForStation('st_base_1');
      expect(samplesInDb.length, equals(25));

      final result = await db.getStationResult('st_base_1');
      expect(result, isNotNull);
      expect(result!.sampleCount, equals(25));
      expect(result.isAccepted, isTrue);
    });

    test('exportBaseStationCsv menulis file CSV yang valid', () async {
      await service.startBaseRecording(
        surveyId: 'surv_base_1',
        stationId: 'st_base_1',
      );

      mockMag.emitSamples(15, 45.0, 0.01);
      await Future.delayed(const Duration(milliseconds: 50));
      await service.stopBaseRecording();

      final tempPath = '${Directory.systemTemp.path}/test_base_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = await service.exportBaseStationCsv(
        filePath: tempPath,
        latitude: -6.2088,
        longitude: 106.8456,
      );

      expect(await file.exists(), isTrue);
      final lines = await file.readAsLines();

      expect(lines[0], contains('# GeoMag Base Station Diurnal Record'));
      expect(lines[4], contains('timestamp_iso,timestamp_ns,raw_x_microt,raw_y_microt,raw_z_microt,total_field_nt,delta_b_nt'));
      expect(lines.length, equals(5 + 15)); // 5 baris header/meta + 15 data

      // Cleanup
      await file.delete();
    });
  });
}
