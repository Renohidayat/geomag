import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase schema & CRUD (ERD)', () {
    test('Device CRUD', () async {
      final device = DevicesCompanion(
        id: const Value('dev-001'),
        model: const Value('Pixel 7'),
        androidVersion: const Value('14'),
        magnetometerChip: const Value('AK09918'),
        noiseFloorNt: const Value(250.0),
      );

      await db.insertDevice(device);

      final fetched = await db.getDevice('dev-001');
      expect(fetched, isNotNull);
      expect(fetched!.model, 'Pixel 7');
      expect(fetched.magnetometerChip, 'AK09918');
      expect(fetched.noiseFloorNt, 250.0);
    });

    test('CalibrationProfile CRUD dan relasi ke Device', () async {
      await db.insertDevice(
        const DevicesCompanion(
          id: Value('dev-001'),
          model: Value('Pixel 7'),
          androidVersion: Value('14'),
          magnetometerChip: Value('AK09918'),
        ),
      );

      final now = DateTime.now();
      await db.insertCalibrationProfile(
        CalibrationProfilesCompanion(
          id: const Value('cal-001'),
          deviceId: const Value('dev-001'),
          timestamp: Value(now),
          hardIronBxMicroT: const Value(1.2),
          hardIronByMicroT: const Value(-3.4),
          hardIronBzMicroT: const Value(0.5),
          matrixA: const Value('1,0,0,0,1,0,0,0,1'),
          residualNt: const Value(120.0),
        ),
      );

      final latest = await db.getLatestCalibrationProfile('dev-001');
      expect(latest, isNotNull);
      expect(latest!.id, 'cal-001');
      expect(latest.hardIronBxMicroT, 1.2);
      expect(latest.residualNt, 120.0);
    });

    test('Survey & Station CRUD', () async {
      await db.insertDevice(
        const DevicesCompanion(
          id: Value('dev-001'),
          model: Value('Pixel 7'),
          androidVersion: Value('14'),
          magnetometerChip: Value('AK09918'),
        ),
      );

      await db.insertSurvey(
        SurveysCompanion(
          id: const Value('srv-001'),
          deviceId: const Value('dev-001'),
          name: const Value('Survei Lapangan A'),
          date: Value(DateTime.now()),
          mode: const Value('rover'),
        ),
      );

      await db.insertStation(
        const StationsCompanion(
          id: Value('stn-001'),
          surveyId: Value('srv-001'),
          sequenceNumber: Value(1),
          latitude: Value(-6.2),
          longitude: Value(106.8),
          gpsAccuracyM: Value(2.5),
        ),
      );

      await db.insertStation(
        const StationsCompanion(
          id: Value('stn-002'),
          surveyId: Value('srv-001'),
          sequenceNumber: Value(2),
          latitude: Value(-6.201),
          longitude: Value(106.801),
          gpsAccuracyM: Value(3.0),
        ),
      );

      final stations = await db.getStationsForSurvey('srv-001');
      expect(stations.length, 2);
      expect(stations[0].sequenceNumber, 1);
      expect(stations[1].sequenceNumber, 2);
    });

    test('Sample append-only & batch insertion', () async {
      await db.insertDevice(
        const DevicesCompanion(
          id: Value('dev-001'),
          model: Value('Pixel 7'),
          androidVersion: Value('14'),
          magnetometerChip: Value('AK09918'),
        ),
      );

      await db.insertSurvey(
        SurveysCompanion(
          id: const Value('srv-001'),
          deviceId: const Value('dev-001'),
          name: const Value('Survei Rover'),
          date: Value(DateTime.now()),
          mode: const Value('rover'),
        ),
      );

      await db.insertStation(
        const StationsCompanion(
          id: Value('stn-001'),
          surveyId: Value('srv-001'),
          sequenceNumber: Value(1),
        ),
      );

      // Simulasikan 5 sampel mentah
      final samples = List.generate(
        5,
        (i) => SamplesCompanion(
          id: Value('sample-$i'),
          stationId: const Value('stn-001'),
          timestampNs: Value(BigInt.from(1000000000 + i * 20000000)),
          rawXMicroT: Value(25.0 + i * 0.1),
          rawYMicroT: Value(-10.0 + i * 0.1),
          rawZMicroT: Value(40.0 + i * 0.1),
          biasXMicroT: const Value(0.0),
          biasYMicroT: const Value(0.0),
          biasZMicroT: const Value(0.0),
          accuracy: const Value(3),
          isUncalibrated: const Value(true),
          batteryTempC: const Value(30.0),
          isCharging: const Value(false),
          isScreenOn: const Value(true),
        ),
      );

      await db.insertSamplesBatch(samples);

      final count = await db.getSampleCountForStation('stn-001');
      expect(count, 5);

      final fetchedSamples = await db.getSamplesForStation('stn-001');
      expect(fetchedSamples.length, 5);
      expect(fetchedSamples.first.rawXMicroT, closeTo(25.0, 1e-6));
      expect(fetchedSamples.last.rawXMicroT, closeTo(25.4, 1e-6));
    });

    test('StationResult & Anomaly calculation storage', () async {
      await db.insertDevice(
        const DevicesCompanion(
          id: Value('dev-001'),
          model: Value('Pixel 7'),
          androidVersion: Value('14'),
          magnetometerChip: Value('AK09918'),
        ),
      );

      await db.insertSurvey(
        SurveysCompanion(
          id: const Value('srv-001'),
          deviceId: const Value('dev-001'),
          name: const Value('Survei'),
          date: Value(DateTime.now()),
          mode: const Value('rover'),
        ),
      );

      await db.insertStation(
        const StationsCompanion(
          id: Value('stn-001'),
          surveyId: Value('srv-001'),
          sequenceNumber: Value(1),
        ),
      );

      // Save station result
      await db.saveStationResult(
        const StationResultsCompanion(
          id: Value('res-001'),
          stationId: Value('stn-001'),
          totalFieldMeanNt: Value(45120.5),
          totalFieldStdNt: Value(85.2),
          sampleCount: Value(150),
          isAccepted: Value(true),
        ),
      );

      final res = await db.getStationResult('stn-001');
      expect(res, isNotNull);
      expect(res!.totalFieldMeanNt, 45120.5);
      expect(res.isAccepted, isTrue);

      // Save anomaly
      await db.saveAnomaly(
        const AnomaliesCompanion(
          id: Value('anom-001'),
          stationId: Value('stn-001'),
          fIgrfNt: Value(45000.0),
          diurnalCorrectionNt: Value(-15.0),
          deltaTNt: Value(135.5),
        ),
      );

      final anom = await db.getAnomaly('stn-001');
      expect(anom, isNotNull);
      expect(anom!.deltaTNt, 135.5);
      expect(anom.fIgrfNt, 45000.0);
    });

    test('deleteStation dan deleteSurveyStations menghapus data sesuai relasi FK', () async {
      await db.insertDevice(
        const DevicesCompanion(
          id: Value('dev-del'),
          model: Value('Test Dev'),
          androidVersion: Value('14'),
          magnetometerChip: Value('AK09918'),
        ),
      );

      await db.insertSurvey(
        SurveysCompanion(
          id: const Value('surv-del'),
          deviceId: const Value('dev-del'),
          name: const Value('Survei Hapus'),
          date: Value(DateTime.now()),
          mode: const Value('rover'),
        ),
      );

      // Insert 2 stations
      for (int i = 1; i <= 2; i++) {
        final stId = 'st-del-$i';
        await db.insertStation(
          StationsCompanion(
            id: Value(stId),
            surveyId: const Value('surv-del'),
            sequenceNumber: Value(i),
          ),
        );
        await db.saveStationResult(
          StationResultsCompanion(
            id: Value('res-del-$i'),
            stationId: Value(stId),
            totalFieldMeanNt: const Value(45000.0),
            totalFieldStdNt: const Value(5.0),
            sampleCount: const Value(100),
            isAccepted: const Value(true),
          ),
        );
        await db.saveAnomaly(
          AnomaliesCompanion(
            id: Value('anom-del-$i'),
            stationId: Value(stId),
            deltaTNt: const Value(10.0),
          ),
        );
      }

      var stations = await db.getStationsForSurvey('surv-del');
      expect(stations.length, 2);

      // Test deleteStation tunggal
      await db.deleteStation('st-del-1');
      stations = await db.getStationsForSurvey('surv-del');
      expect(stations.length, 1);
      expect(stations.first.id, 'st-del-2');

      // Test deleteSurveyStations
      await db.deleteSurveyStations('surv-del');
      stations = await db.getStationsForSurvey('surv-del');
      expect(stations, isEmpty);
    });

    test('factoryResetDatabase membersihkan seluruh tabel', () async {
      await db.insertDevice(
        const DevicesCompanion(
          id: Value('dev-reset'),
          model: Value('Reset Dev'),
          androidVersion: Value('14'),
          magnetometerChip: Value('AK09918'),
        ),
      );
      await db.insertSurvey(
        SurveysCompanion(
          id: const Value('surv-reset'),
          deviceId: const Value('dev-reset'),
          name: const Value('Survei Reset'),
          date: Value(DateTime.now()),
          mode: const Value('rover'),
        ),
      );

      var stats = await db.getDatabaseStats();
      expect(stats.devices, 1);
      expect(stats.surveys, 1);

      await db.factoryResetDatabase();
      stats = await db.getDatabaseStats();
      expect(stats.devices, 0);
      expect(stats.surveys, 0);
      expect(stats.stations, 0);
    });

    test('Foreign key enforcement mencegah orphan data', () async {
      expect(
        () async => await db.insertStation(
          const StationsCompanion(
            id: Value('orphan-stn'),
            surveyId: Value('non-existent-survey'),
            sequenceNumber: Value(1),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
