import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/services/survey_quality_report_service.dart';

void main() {
  late AppDatabase db;
  late SurveyQualityReportService reportService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    reportService = SurveyQualityReportService(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('generateReport menangani survei kosong tanpa stasiun', () async {
    final now = DateTime.now();
    await db.into(db.devices).insert(
          DevicesCompanion.insert(
            id: 'DEV_01',
            model: 'Test Device',
            androidVersion: '14',
            magnetometerChip: 'AK09918',
          ),
        );

    await db.into(db.surveys).insert(
          SurveysCompanion.insert(
            id: 'SURV_EMPTY',
            deviceId: 'DEV_01',
            name: 'Survei Kosong',
            date: now,
            mode: 'rover',
          ),
        );

    final report = await reportService.generateReport('SURV_EMPTY');
    expect(report.totalStations, 0);
    expect(report.acceptedRatio, 0.0);
    expect(report.overallScore, 0);
    expect(report.grade, QualityGrade.gradeD);
    expect(report.findings, isNotEmpty);
    expect(report.recommendations, isNotEmpty);
  });

  test('generateReport menghitung skor, grade, audit kalibrasi, dan rekomendasi dengan benar', () async {
    final now = DateTime.now();

    // 1. Device
    await db.into(db.devices).insert(
          DevicesCompanion.insert(
            id: 'DEV_01',
            model: 'Test Device',
            androidVersion: '14',
            magnetometerChip: 'AK09918',
          ),
        );

    // 2. Profil Kalibrasi Aktif
    await db.into(db.calibrationProfiles).insert(
          CalibrationProfilesCompanion.insert(
            id: 'CAL_01',
            deviceId: 'DEV_01',
            timestamp: now.subtract(const Duration(days: 2)),
            hardIronBxMicroT: 1.2,
            hardIronByMicroT: -0.8,
            hardIronBzMicroT: 0.5,
            matrixA: '1,0,0,0,1,0,0,0,1',
            residualNt: 28.5,
            createdAt: drift.Value(now.subtract(const Duration(days: 2))),
          ),
        );

    // 3. Base Survey
    await db.into(db.surveys).insert(
          SurveysCompanion.insert(
            id: 'BASE_01',
            deviceId: 'DEV_01',
            name: 'Base Station Kontinu',
            date: now,
            mode: 'base',
          ),
        );

    await db.into(db.stations).insert(
          StationsCompanion.insert(
            id: 'BS_POINT_01',
            surveyId: 'BASE_01',
            sequenceNumber: 1,
          ),
        );

    // 4. Rover Survey (tertaut ke Base)
    await db.into(db.surveys).insert(
          SurveysCompanion.insert(
            id: 'SURV_01',
            deviceId: 'DEV_01',
            name: 'Survei Lapangan Tambang',
            date: now,
            mode: 'rover',
            baseSurveyId: const drift.Value('BASE_01'),
          ),
        );

    // 5. Masukkan 4 stasiun rover: 3 ACCEPTED, 1 REJECTED
    final stations = [
      {'id': 'ST_01', 'isAcc': true, 'std': 4.2},
      {'id': 'ST_02', 'isAcc': true, 'std': 6.5},
      {'id': 'ST_03', 'isAcc': true, 'std': 8.1},
      {'id': 'ST_04', 'isAcc': false, 'std': 1250.0},
    ];

    for (int i = 0; i < stations.length; i++) {
      final s = stations[i];
      final stId = s['id'] as String;
      final isAcc = s['isAcc'] as bool;
      final std = s['std'] as double;

      await db.into(db.stations).insert(
            StationsCompanion.insert(
              id: stId,
              surveyId: 'SURV_01',
              sequenceNumber: i + 1,
            ),
          );

      await db.into(db.stationResults).insert(
            StationResultsCompanion.insert(
              id: 'RES_$stId',
              stationId: stId,
              totalFieldMeanNt: 45000.0,
              totalFieldStdNt: std,
              sampleCount: 600,
              isAccepted: isAcc,
              rejectionReason: isAcc ? const drift.Value(null) : const drift.Value('Simpangan baku tinggi'),
            ),
          );
    }

    final report = await reportService.generateReport('SURV_01');

    expect(report.totalStations, 4);
    expect(report.acceptedStations, 3);
    expect(report.rejectedStations, 1);
    expect(report.acceptedRatio, 0.75);

    expect(report.hasCalibration, isTrue);
    expect(report.calibrationResidualNt, 28.5);
    expect(report.calibrationAgeDays, 2);

    expect(report.hasBaseStation, isTrue);
    expect(report.baseStationPoints, 1);

    // Skor harus tinggi karena mayoritas diterima, ada kalibrasi segar, dan ada base station
    expect(report.overallScore, greaterThanOrEqualTo(65));
    expect(report.grade, isIn([QualityGrade.gradeA, QualityGrade.gradeB, QualityGrade.gradeC]));

    // Temuan harus mencatat stasiun ditolak
    expect(report.findings.any((f) => f.contains('DITOLAK')), isTrue);
    expect(report.recommendations.any((r) => r.contains('pengukuran ulang')), isTrue);

    // Markdown harus terformat lengkap
    final md = report.toMarkdown();
    expect(md, contains('# Laporan Audit Mutu Survei Geomagnetik: Survei Lapangan Tambang'));
    expect(md, contains('3 (75.0%)'));
    expect(md, contains('Terpasang'));
    expect(md, contains('Terhubung'));
  });
}
