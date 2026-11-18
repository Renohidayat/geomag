import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/services/igrf_service.dart';

void main() {
  const service = IgrfService();

  group('IGRF-14 Benchmark Verification (Dart vs Python / IAGA ppigrf)', () {
    test('Jakarta benchmark (2025.0) matches Python reference < 0.05 nT', () {
      // Jakarta: lat=-6.2088, lon=106.8456, h=0
      // Reference Python ppigrf: Be=415.2501, Bn=38853.7151, Bu=21566.5007 (Z_down=-21566.5007), F=44439.8195
      final res = service.calculateForDecimalYear(
        latitudeDeg: -6.2088,
        longitudeDeg: 106.8456,
        altitudeKm: 0.0,
        decimalYear: 2025.0,
      );

      expect(res.xNorthNt, closeTo(38853.72, 0.05));
      expect(res.yEastNt, closeTo(415.25, 0.05));
      expect(res.zDownNt, closeTo(-21566.50, 0.05));
      expect(res.fTotalNt, closeTo(44439.82, 0.05));
      expect(res.declinationDeg, closeTo(0.61, 0.05));
      expect(res.inclinationDeg, closeTo(-29.03, 0.05));
    });

    test('Bandung benchmark (2025.5) matches Python reference < 0.05 nT', () {
      // Bandung: lat=-6.9175, lon=107.6191, h=0.768 km
      final res = service.calculateForDecimalYear(
        latitudeDeg: -6.9175,
        longitudeDeg: 107.6191,
        altitudeKm: 0.768,
        decimalYear: 2025.5,
      );

      expect(res.xNorthNt, closeTo(38580.12, 0.05));
      expect(res.yEastNt, closeTo(453.09, 0.05));
      expect(res.zDownNt, closeTo(-22531.44, 0.05));
      expect(res.fTotalNt, closeTo(44679.94, 0.05));
    });

    test('Yogyakarta benchmark (2026.0) with Secular Variation projection', () {
      final res = service.calculateForDecimalYear(
        latitudeDeg: -7.7956,
        longitudeDeg: 110.3695,
        altitudeKm: 0.113,
        decimalYear: 2026.0,
      );

      expect(res.xNorthNt, closeTo(38256.43, 0.1));
      expect(res.yEastNt, closeTo(524.25, 0.1));
      expect(res.zDownNt, closeTo(-23490.77, 0.1));
      expect(res.fTotalNt, closeTo(44895.95, 0.1));
    });

    test('Medan benchmark (near equator, low magnetic inclination)', () {
      final res = service.calculateForDecimalYear(
        latitudeDeg: 3.5952,
        longitudeDeg: 98.6722,
        altitudeKm: 0.026,
        decimalYear: 2025.0,
      );

      expect(res.xNorthNt, closeTo(41533.56, 0.05));
      expect(res.yEastNt, closeTo(-215.37, 0.05));
      expect(res.zDownNt, closeTo(-6048.38, 0.05));
      expect(res.fTotalNt, closeTo(41972.20, 0.05));
      expect(res.inclinationDeg, closeTo(-8.29, 0.05));
    });

    test('London benchmark (high latitude, steep magnetic inclination)', () {
      final res = service.calculateForDecimalYear(
        latitudeDeg: 51.5074,
        longitudeDeg: -0.1278,
        altitudeKm: 0.035,
        decimalYear: 2025.0,
      );

      expect(res.xNorthNt, closeTo(19543.29, 0.05));
      expect(res.yEastNt, closeTo(306.58, 0.05));
      expect(res.zDownNt, closeTo(45003.05, 0.05));
      expect(res.fTotalNt, closeTo(49064.34, 0.05));
      expect(res.inclinationDeg, closeTo(66.52, 0.05));
    });
  });

  group('Anomaly Calculation and Storage', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('calculateDeltaTNt calculates correct anomaly with and without diurnal correction', () {
      // B_obs = 45000.0, F_IGRF = 44439.8, B_diurnal = +10.0
      // Delta T = 45000.0 - 10.0 - 44439.8 = 550.2 nT
      final deltaWithDiurnal = service.calculateDeltaTNt(
        observedTotalFieldNt: 45000.0,
        diurnalCorrectionNt: 10.0,
        fIgrfNt: 44439.8,
      );
      expect(deltaWithDiurnal, closeTo(550.2, 1e-4));

      // Without diurnal correction:
      // Delta T = 45000.0 - 44439.8 = 560.2 nT
      final deltaNoDiurnal = service.calculateDeltaTNt(
        observedTotalFieldNt: 45000.0,
        diurnalCorrectionNt: null,
        fIgrfNt: 44439.8,
      );
      expect(deltaNoDiurnal, closeTo(560.2, 1e-4));
    });

    test('computeAndSaveAnomaly computes IGRF and saves Anomaly entity to Drift DB', () async {
      // 1. Insert prerequisites (Device, Survey, Station)
      final device = DevicesCompanion.insert(
        id: 'dev-01',
        model: 'Pixel 8',
        androidVersion: '14',
        magnetometerChip: 'AK09918',
        noiseFloorNt: const Value(500.0),
      );
      await db.into(db.devices).insert(device);

      final survey = SurveysCompanion.insert(
        id: 'srv-01',
        deviceId: 'dev-01',
        name: 'Survei Geofisika Lapangan',
        date: DateTime.utc(2025, 1, 1),
        mode: 'rover',
      );
      await db.into(db.surveys).insert(survey);

      final station = StationsCompanion.insert(
        id: 'st-01',
        surveyId: 'srv-01',
        sequenceNumber: 1,
        latitude: const Value(-6.2088),
        longitude: const Value(106.8456),
      );
      await db.into(db.stations).insert(station);

      // 2. Compute and save anomaly
      final anomaly = await service.computeAndSaveAnomaly(
        database: db,
        stationId: 'st-01',
        observedTotalFieldNt: 44900.0,
        diurnalCorrectionNt: 15.0,
        latitudeDeg: -6.2088,
        longitudeDeg: 106.8456,
        altitudeKm: 0.0,
        date: DateTime.utc(2025, 1, 1),
      );

      expect(anomaly.stationId, 'st-01');
      expect(anomaly.fIgrfNt, closeTo(44439.82, 0.05));
      expect(anomaly.diurnalCorrectionNt, 15.0);
      // Delta T = 44900 - 15 - 44439.82 = 445.18 nT
      expect(anomaly.deltaTNt, closeTo(445.18, 0.05));

      // 3. Verify querying back from database
      final queried = await (db.select(db.anomalies)
            ..where((tbl) => tbl.stationId.equals('st-01')))
          .getSingle();
      expect(queried.id, 'anom-st-01');
      expect(queried.deltaTNt, closeTo(445.18, 0.05));
    });
  });
}

