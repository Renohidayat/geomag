import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/sensor_info.dart';
import 'package:geomag/screens/anomaly_map_screen.dart';
import 'package:geomag/services/magnetometer_service.dart';

class MockMagnetometerService extends MagnetometerService {
  final _controller = StreamController<MagnetometerSample>.broadcast();
  final SensorInfo _info;

  MockMagnetometerService({SensorInfo? info})
      : _info = info ??
            const SensorInfo(
              available: true,
              isUncalibrated: true,
              name: 'AK09918 Uncalibrated',
              vendor: 'Asahi Kasei',
              version: 1,
              resolutionMicroT: 0.15,
              maxRangeMicroT: 4912.0,
              minDelayUs: 20000,
            );

  @override
  Stream<MagnetometerSample> get sampleStream => _controller.stream;

  @override
  Future<SensorInfo> getSensorInfo() async => _info;

  void emitSample(MagnetometerSample sample) {
    _controller.add(sample);
  }

  void close() {
    _controller.close();
  }
}

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
    expect(find.text('Peta Anomali 2D'), findsOneWidget);

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

  testWidgets(
      'AnomalyMapScreen menampilkan Kompas Arah, FilterChips, dan label legenda ramah pemula',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnomalyMapScreen(database: db),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi Kompas Arah Utara
    expect(find.text('Arah Utara (N)'), findsOneWidget);
    expect(find.text('Sumbu Atas (+Y)'), findsOneWidget);

    // Verifikasi FilterChips kontrol tampilan
    expect(find.text('Jalur Rute'), findsOneWidget);
    expect(find.text('No. Titik'), findsOneWidget);
    expect(find.text('Live Sensor'), findsOneWidget);

    // Verifikasi label ramah pemula di legenda colormap
    expect(find.text('🔵 Medan Rendah'), findsOneWidget);
    expect(find.text('🟢 Normal (Alami)'), findsOneWidget);
    expect(find.text('🔴 Tinggi (Logam/Kabel)'), findsOneWidget);

    // Verifikasi ketukan pada FilterChip berfungsi
    await tester.tap(find.text('Jalur Rute'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No. Titik'));
    await tester.pumpAndSettle();

    // Verifikasi panduan bantuan memiliki bagian orientasi dan navigasi lapangan
    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();

    expect(find.text('3. Orientasi & Navigasi Lapangan'), findsOneWidget);
    expect(find.text('Kompas Arah (N)'), findsOneWidget);
    expect(find.text('Jalur Urutan Survei'), findsOneWidget);
    expect(find.text('Monitor Sensor Live'), findsOneWidget);

    final okBtn = find.text('Saya Mengerti');
    await tester.ensureVisible(okBtn);
    await tester.tap(okBtn);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'AnomalyMapScreen memperbarui Live Sensor Monitor saat menerima data magnetometer',
      (tester) async {
    final mockService = MockMagnetometerService();

    await tester.pumpWidget(
      MaterialApp(
        home: AnomalyMapScreen(
          database: db,
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Monitor sensor HP live muncul
    expect(find.text('Monitor Sensor HP Real-Time'), findsOneWidget);
    expect(find.text('Menghubungkan ke Sensor...'), findsOneWidget);

    // Kirim sampel medan normal (~44 µT)
    mockService.emitSample(
      const MagnetometerSample(
        timestampNs: 1000000,
        rawXMicroT: 20.0,
        rawYMicroT: 25.0,
        rawZMicroT: 30.0,
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
    await tester.pump(const Duration(milliseconds: 100));

    // Total = sqrt(20^2 + 25^2 + 30^2) = sqrt(400 + 625 + 900) = sqrt(1925) = 43.87 µT (< 48 µT -> Normal)
    expect(find.text('Medan Normal (Latar Alami)'), findsOneWidget);
    expect(find.textContaining('43.9 µT'), findsOneWidget);

    // Kirim sampel medan tinggi (> 58 µT)
    mockService.emitSample(
      const MagnetometerSample(
        timestampNs: 2000000,
        rawXMicroT: 35.0,
        rawYMicroT: 40.0,
        rawZMicroT: 45.0,
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
    await tester.pump(const Duration(milliseconds: 100));

    // Total = sqrt(35^2 + 40^2 + 45^2) = sqrt(1225 + 1600 + 2025) = sqrt(4850) = 69.64 µT (> 58 µT -> Tinggi)
    expect(find.text('Anomali Tinggi (Terdeteksi Besi / Kabel Listrik)'), findsOneWidget);
    expect(find.textContaining('69.6 µT'), findsOneWidget);

    mockService.close();
  });

  testWidgets(
      'AnomalyMapScreen menampilkan Ringkasan Ruangan dan dapat beralih ke Rincian Titik',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnomalyMapScreen(database: db),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi chip tab Ringkasan Ruangan dan Rincian Titik
    expect(find.text('Ringkasan Ruangan'), findsOneWidget);
    expect(find.textContaining('Analisis Keseluruhan Ruangan'), findsOneWidget);
    expect(find.text('🟢 Paling Tenang'), findsOneWidget);
    expect(find.text('🔴 Paling Kuat'), findsOneWidget);
    expect(find.text('📏 Selisih Ruangan'), findsOneWidget);

    // Beralih ke tab Rincian Titik
    expect(find.textContaining('Rincian Titik #'), findsOneWidget);
    await tester.tap(find.textContaining('Rincian Titik #'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Titik #'), findsWidgets);

    // Beralih kembali ke Ringkasan Ruangan
    await tester.tap(find.text('Ringkasan Ruangan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Analisis Keseluruhan Ruangan'), findsOneWidget);
  });
}
