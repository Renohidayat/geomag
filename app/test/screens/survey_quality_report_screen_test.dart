import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/screens/survey_quality_report_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
      'SurveyQualityReportScreen menampilkan pesan jika belum ada survei rover',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SurveyQualityReportScreen(database: db),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Laporan Mutu Survei'), findsOneWidget);
    expect(find.text('Belum ada survei rover tercatat di database.'), findsOneWidget);
  });

  testWidgets(
      'SurveyQualityReportScreen menampilkan kartu skor, breakdown, dan rekomendasi',
      (tester) async {
    final now = DateTime.now();

    await db.into(db.devices).insert(
          DevicesCompanion.insert(
            id: 'DEV_01',
            model: 'Test Phone',
            androidVersion: '14',
            magnetometerChip: 'AK09918',
          ),
        );

    await db.into(db.surveys).insert(
          SurveysCompanion.insert(
            id: 'SURV_01',
            deviceId: 'DEV_01',
            name: 'Survei Geologi Gunung Mas',
            date: now,
            mode: 'rover',
          ),
        );

    await db.into(db.stations).insert(
          StationsCompanion.insert(
            id: 'ST_01',
            surveyId: 'SURV_01',
            sequenceNumber: 1,
          ),
        );

    await db.into(db.stationResults).insert(
          StationResultsCompanion.insert(
            id: 'RES_ST_01',
            stationId: 'ST_01',
            totalFieldMeanNt: 45000.0,
            totalFieldStdNt: 3.5,
            sampleCount: 600,
            isAccepted: true,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: SurveyQualityReportScreen(database: db),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi dropdown survei
    expect(find.text('Survei Geologi Gunung Mas'), findsOneWidget);

    // Verifikasi komponen kartu skor & kinerja
    expect(find.text('SKOR MUTU SURVEI'), findsOneWidget);
    expect(find.text('Kinerja Stasiun Rover'), findsOneWidget);
    expect(find.text('Diterima'), findsOneWidget);

    // Verifikasi audit instrumen
    expect(find.text('Audit Instrumen & Reduksi'), findsOneWidget);
    expect(find.text('Kalibrasi Ellipsoid Sensor'), findsOneWidget);

    // Verifikasi tombol salin & ekspor
    expect(find.byIcon(Icons.copy_all), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);
  });
}
