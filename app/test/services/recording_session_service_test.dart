import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/services/recording_session_service.dart';

void main() {
  group('RecordingSessionService', () {
    late AppDatabase database;
    late RecordingSessionService sessionService;
    late Directory tempDir;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      sessionService = RecordingSessionService(
        database: database,
        batchSize: 5, // batch kecil untuk memicu auto flush dalam tes
      );
      tempDir = await Directory.systemTemp.createTemp('geomag_session_test_');
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('startSession & zero data loss saat stream sampel berhenti', () async {
      final controller = StreamController<MagnetometerSample>();

      await sessionService.startSession(
        sampleStream: controller.stream,
        surveyId: 'survey-001',
        stationId: 'stn-001',
        deviceId: 'device-001',
      );

      expect(sessionService.isRecording, isTrue);
      expect(sessionService.activeStationId, 'stn-001');

      // Kirim 12 sampel (melewati 2 batch @5 + 2 sisa)
      for (var i = 1; i <= 12; i++) {
        controller.add(
          MagnetometerSample(
            timestampNs: 1000000000 + i * 20000000,
            rawXMicroT: 20.0 + i,
            rawYMicroT: -10.0 + i,
            rawZMicroT: 40.0 + i,
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

      // Tunggu event stream diproses
      await pumpEventQueue();

      expect(sessionService.recordedSampleCount, 12);

      // Stop session harus flush sisa buffer ke database
      await sessionService.stopSession();
      expect(sessionService.isRecording, isFalse);

      final dbCount = await database.getSampleCountForStation('stn-001');
      expect(dbCount, 12); // ZERO data loss

      final dbSamples = await database.getSamplesForStation('stn-001');
      expect(dbSamples.length, 12);
      expect(dbSamples.first.rawXMicroT, 21.0);
      expect(dbSamples.last.rawXMicroT, 32.0);

      await controller.close();
    });

    test('exportCurrentStationToCsv mengekspor data stasiun aktif', () async {
      final controller = StreamController<MagnetometerSample>();

      await sessionService.startSession(
        sampleStream: controller.stream,
        surveyId: 'survey-export',
        stationId: 'stn-export',
        deviceId: 'dev-export',
      );

      controller.add(
        const MagnetometerSample(
          timestampNs: 2000000000,
          rawXMicroT: 15.0,
          rawYMicroT: 25.0,
          rawZMicroT: 35.0,
          biasXMicroT: 0.1,
          biasYMicroT: 0.2,
          biasZMicroT: 0.3,
          accuracy: 3,
          isUncalibrated: true,
          batteryTempC: 28.0,
          isCharging: false,
          isScreenOn: true,
        ),
      );

      await pumpEventQueue();
      await sessionService.stopSession();

      final csvFile = await sessionService.exportCurrentStationToCsv(tempDir);
      expect(await csvFile.exists(), isTrue);

      final content = await csvFile.readAsString();
      expect(content, contains('timestamp_ns,raw_x_micro_t'));
      expect(content, contains('2000000000,15.0,25.0,35.0'));

      await controller.close();
    });
  });
}
