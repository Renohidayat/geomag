import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/anomalies.dart';
import 'tables/calibration_profiles.dart';
import 'tables/devices.dart';
import 'tables/samples.dart';
import 'tables/station_results.dart';
import 'tables/stations.dart';
import 'tables/surveys.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Devices,
  CalibrationProfiles,
  Surveys,
  Stations,
  Samples,
  StationResults,
  Anomalies,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        // Aktifkan foreign keys di SQLite
        await customStatement('PRAGMA foreign_keys = ON');
      },
      onCreate: (m) async {
        await m.createAll();
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'geomag_database');
  }

  // --- Helper CRUD & Queries ---

  // Devices
  Future<int> insertDevice(DevicesCompanion device) =>
      into(devices).insert(device, mode: InsertMode.insertOrReplace);

  Future<Device?> getDevice(String id) =>
      (select(devices)..where((d) => d.id.equals(id))).getSingleOrNull();

  // Calibration Profiles
  Future<int> insertCalibrationProfile(CalibrationProfilesCompanion profile) =>
      into(calibrationProfiles).insert(profile);

  Future<CalibrationProfile?> getLatestCalibrationProfile(String deviceId) =>
      (select(calibrationProfiles)
            ..where((c) => c.deviceId.equals(deviceId))
            ..orderBy([(c) => OrderingTerm.desc(c.timestamp)])
            ..limit(1))
          .getSingleOrNull();

  // Surveys
  Future<int> insertSurvey(SurveysCompanion survey) =>
      into(surveys).insert(survey);

  Future<Survey?> getSurvey(String id) =>
      (select(surveys)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<List<Survey>> getAllSurveys() =>
      (select(surveys)..orderBy([(s) => OrderingTerm.desc(s.date)])).get();

  // Stations
  Future<int> insertStation(StationsCompanion station) =>
      into(stations).insert(station);

  Future<List<Station>> getStationsForSurvey(String surveyId) =>
      (select(stations)
            ..where((s) => s.surveyId.equals(surveyId))
            ..orderBy([(s) => OrderingTerm.asc(s.sequenceNumber)]))
          .get();

  // Samples (APPEND-ONLY: hanya insert / insertAll, TIDAK ADA update atau delete)
  Future<int> insertSample(SamplesCompanion sample) =>
      into(samples).insert(sample);

  Future<void> insertSamplesBatch(List<SamplesCompanion> sampleList) async {
    await batch((b) {
      b.insertAll(samples, sampleList);
    });
  }

  Future<List<Sample>> getSamplesForStation(String stationId) =>
      (select(samples)
            ..where((s) => s.stationId.equals(stationId))
            ..orderBy([(s) => OrderingTerm.asc(s.timestampNs)]))
          .get();

  Future<int> getSampleCountForStation(String stationId) async {
    final count = samples.id.count();
    final query = selectOnly(samples)
      ..where(samples.stationId.equals(stationId))
      ..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // StationResults (Boleh dihitung ulang: insertOrReplace)
  Future<int> saveStationResult(StationResultsCompanion result) =>
      into(stationResults).insert(result, mode: InsertMode.insertOrReplace);

  Future<StationResult?> getStationResult(String stationId) =>
      (select(stationResults)..where((r) => r.stationId.equals(stationId)))
          .getSingleOrNull();

  // Anomalies (Boleh dihitung ulang: insertOrReplace)
  Future<int> saveAnomaly(AnomaliesCompanion anomaly) =>
      into(anomalies).insert(anomaly, mode: InsertMode.insertOrReplace);

  Future<Anomaly?> getAnomaly(String stationId) =>
      (select(anomalies)..where((a) => a.stationId.equals(stationId)))
          .getSingleOrNull();

  // Penghapusan data stasiun dan reset survei (mengikuti urutan integritas foreign key)
  Future<void> deleteStation(String stationId) async {
    await transaction(() async {
      await (delete(anomalies)..where((tbl) => tbl.stationId.equals(stationId))).go();
      await (delete(stationResults)..where((tbl) => tbl.stationId.equals(stationId))).go();
      await (delete(samples)..where((tbl) => tbl.stationId.equals(stationId))).go();
      await (delete(stations)..where((tbl) => tbl.id.equals(stationId))).go();
    });
  }

  Future<void> deleteSurveyStations(String surveyId) async {
    await transaction(() async {
      final stList = await (select(stations)..where((tbl) => tbl.surveyId.equals(surveyId))).get();
      final stIds = stList.map((s) => s.id).toList();
      if (stIds.isNotEmpty) {
        await (delete(anomalies)..where((tbl) => tbl.stationId.isIn(stIds))).go();
        await (delete(stationResults)..where((tbl) => tbl.stationId.isIn(stIds))).go();
        await (delete(samples)..where((tbl) => tbl.stationId.isIn(stIds))).go();
        await (delete(stations)..where((tbl) => tbl.surveyId.equals(surveyId))).go();
      }
    });
  }

  Future<void> factoryResetDatabase() async {
    await transaction(() async {
      await delete(anomalies).go();
      await delete(stationResults).go();
      await delete(samples).go();
      await delete(stations).go();
      await delete(surveys).go();
      await delete(calibrationProfiles).go();
      await delete(devices).go();
    });
  }

  Future<({int devices, int surveys, int stations, int samples, int calibrations})> getDatabaseStats() async {
    final devCount = await select(devices).get().then((l) => l.length);
    final survCount = await select(surveys).get().then((l) => l.length);
    final stCount = await select(stations).get().then((l) => l.length);
    final smpCount = await select(samples).get().then((l) => l.length);
    final calCount = await select(calibrationProfiles).get().then((l) => l.length);
    return (
      devices: devCount,
      surveys: survCount,
      stations: stCount,
      samples: smpCount,
      calibrations: calCount,
    );
  }
}
