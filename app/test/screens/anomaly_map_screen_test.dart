import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/screens/anomaly_map_screen.dart';

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
      'AnomalyMapScreen otomatis membuat peta demo jika belum ada data survei',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnomalyMapScreen(database: db),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi AppBar
    expect(find.text('Peta Anomali Geomagnetik'), findsOneWidget);

    // Verifikasi segmen layer
    expect(find.text('B Obs'), findsWidgets);
    expect(find.text('Anomali ΔT'), findsWidgets);
    expect(find.text('|AS| 3D'), findsWidgets);
    expect(find.text('RTP'), findsWidgets);

    // Canvas peta interaktif dan colorbar muncul
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.textContaining('nT'), findsWidgets);
  });

  testWidgets(
      'AnomalyMapScreen dapat beralih layer ke B Obs dan |AS| 3D',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnomalyMapScreen(database: db),
      ),
    );

    await tester.pumpAndSettle();

    // Beralih ke B Obs
    await tester.tap(find.text('B Obs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('B Obs'), findsWidgets);

    // Beralih ke |AS| 3D
    await tester.tap(find.text('|AS| 3D'));
    await tester.pumpAndSettle();
    expect(find.textContaining('nT/m'), findsWidgets);

    // Beralih ke RTP
    await tester.tap(find.text('RTP'));
    await tester.pumpAndSettle();
    expect(find.textContaining('nT'), findsWidgets);
  });

  testWidgets(
      'AnomalyMapScreen membaca data stasiun dari database dan menampilkan survei',
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
            id: 'SURV_TEST_01',
            deviceId: 'DEV_01',
            name: 'Survei Geofisika Lapangan',
            date: now,
            mode: 'rover',
          ),
        );

    // Masukkan 4 stasiun membentuk grid 2x2
    final coords = [
      {'id': 'ST_01', 'seq': 1, 'x': 0.0, 'y': 0.0, 'b': 45000.0, 'dt': 25.0},
      {'id': 'ST_02', 'seq': 2, 'x': 10.0, 'y': 0.0, 'b': 45050.0, 'dt': 75.0},
      {'id': 'ST_03', 'seq': 3, 'x': 0.0, 'y': 10.0, 'b': 45030.0, 'dt': 55.0},
      {'id': 'ST_04', 'seq': 4, 'x': 10.0, 'y': 10.0, 'b': 45100.0, 'dt': 125.0},
    ];

    for (final c in coords) {
      final stId = c['id'] as String;
      await db.into(db.stations).insert(
            StationsCompanion.insert(
              id: stId,
              surveyId: 'SURV_TEST_01',
              sequenceNumber: c['seq'] as int,
              latitude: const drift.Value(-6.89),
              longitude: const drift.Value(107.61),
              localX: drift.Value(c['x'] as double),
              localY: drift.Value(c['y'] as double),
            ),
          );

      await db.into(db.stationResults).insert(
            StationResultsCompanion.insert(
              id: 'RES_$stId',
              stationId: stId,
              totalFieldMeanNt: c['b'] as double,
              totalFieldStdNt: 2.0,
              sampleCount: 600,
              isAccepted: true,
            ),
          );

      await db.into(db.anomalies).insert(
            AnomaliesCompanion.insert(
              id: 'ANOM_$stId',
              stationId: stId,
              diurnalCorrectionNt: const drift.Value(2.5),
              fIgrfNt: const drift.Value(44972.5),
              deltaTNt: drift.Value(c['dt'] as double),
            ),
          );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: AnomalyMapScreen(database: db),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi dropdown survei menampilkan survei dari DB
    expect(find.text('Survei Geofisika Lapangan'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets(
      'AnomalyMapScreen membuka dialog ekspor QGIS saat tombol download ditekan',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnomalyMapScreen(database: db),
      ),
    );

    await tester.pumpAndSettle();

    // Tekan tombol ekspor GIS
    await tester.tap(find.byIcon(Icons.file_download_outlined));
    await tester.pumpAndSettle();

    // Dialog bottom sheet ekspor harus muncul
    expect(find.text('Ekspor Data QGIS / GIS'), findsOneWidget);
    expect(find.text('ESRI ASCII Grid (.asc)'), findsOneWidget);
    expect(find.text('GeoJSON Titik Stasiun (.geojson)'), findsOneWidget);
    expect(find.text('CSV Anomali Terpadu (.csv)'), findsOneWidget);
    expect(find.text('Ekspor Semua Paket GIS (Lengkap)'), findsOneWidget);
  });

  testWidgets(
      'AnomalyMapScreen menampilkan banner ramah pemula jika stasiun kurang dari 3 titik',
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
            id: 'SURV_SINGLE',
            deviceId: 'DEV_01',
            name: 'Survei 1 Titik',
            date: now,
            mode: 'rover',
          ),
        );
    await db.into(db.stations).insert(
          StationsCompanion.insert(
            id: 'ST_01',
            surveyId: 'SURV_SINGLE',
            sequenceNumber: 1,
            localX: const drift.Value(0.0),
            localY: const drift.Value(0.0),
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: AnomalyMapScreen(database: db),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Baru Ada 1 Titik Stasiun'), findsOneWidget);
    expect(find.text('Tampilkan Peta Contoh Demo Simulasi'), findsOneWidget);

    // Ketuk tombol tampilkan peta demo simulasi
    await tester.tap(find.text('Tampilkan Peta Contoh Demo Simulasi'));
    await tester.pumpAndSettle();

    // Banner hilang karena sudah ada 16 stasiun demo
    expect(find.text('Tampilkan Peta Contoh Demo Simulasi'), findsNothing);
  });
}
