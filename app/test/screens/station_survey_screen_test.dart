import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/sensor_info.dart';
import 'package:geomag/screens/station_survey_screen.dart';
import 'package:geomag/services/magnetometer_service.dart';

class MockStationMagService extends MagnetometerService {
  final _controller = StreamController<MagnetometerSample>.broadcast();

  @override
  Stream<MagnetometerSample> get sampleStream => _controller.stream;

  @override
  Future<SensorInfo> getSensorInfo() async => const SensorInfo(
        available: true,
        isUncalibrated: true,
        name: 'Mock Test Magnetometer',
      );

  void emitSamples(int count, double baseMicroT, double noiseAmp) {
    for (var i = 0; i < count; i++) {
      _controller.add(
        MagnetometerSample(
          timestampNs: 1000000000 + i * 20000000,
          rawXMicroT: baseMicroT + (i.isEven ? noiseAmp : -noiseAmp),
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
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'StationSurveyScreen alur rekam stasiun stabil, simpan database, dan auto-increment stasiun',
      (tester) async {
    final mockService = MockStationMagService();
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: StationSurveyScreen(
          service: mockService,
          database: testDb,
          recordDurationSeconds: 2, // 2 detik untuk tes cepat
          minSamples: 10,
          maxStdDevNt: 500.0,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi UI Awal
    expect(find.text('Survei Stasiun Rover'), findsOneWidget);
    expect(find.text('Survei Lapangan Utama'), findsOneWidget);
    expect(find.text('Stasiun #1'), findsOneWidget);
    expect(find.text('Mulai Rekam Stasiun (2s)'), findsOneWidget);

    // Mulai rekam stasiun
    await tester.tap(find.text('Mulai Rekam Stasiun (2s)'));
    await tester.pump();

    // Pancarkan 15 sampel stabil (+- 50 nT)
    mockService.emitSamples(15, 45.0, 0.05);
    await tester.pump();

    // Fast forward 2 detik
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Verifikasi hasil evaluasi mutu: ACCEPTED
    expect(find.text('Status: ACCEPTED'), findsOneWidget);
    expect(find.text('Simpan Stasiun ke Database'), findsOneWidget);

    // Simpan stasiun ke database
    final saveButton = find.text('Simpan Stasiun ke Database');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verifikasi nomor stasiun naik menjadi #2
    expect(find.text('Stasiun #2'), findsOneWidget);

    // Verifikasi di database Drift
    final stations = await testDb.select(testDb.stations).get();
    expect(stations.length, equals(1));
    expect(stations.first.sequenceNumber, equals(1));
    expect(stations.first.environmentNotes, contains('ACCEPTED'));

    final results = await testDb.select(testDb.stationResults).get();
    expect(results.length, equals(1));
    expect(results.first.totalFieldMeanNt, closeTo(45000.0, 10.0));
    expect(results.first.sampleCount, equals(15));
    expect(results.first.isAccepted, isTrue);

    final samples = await testDb.select(testDb.samples).get();
    expect(samples.length, equals(15));

    mockService.close();
    await testDb.close();
  });

  testWidgets(
      'StationSurveyScreen penolakan otomatis stasiun dengan noise tinggi (REJECTED)',
      (tester) async {
    final mockService = MockStationMagService();
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: StationSurveyScreen(
          service: mockService,
          database: testDb,
          recordDurationSeconds: 2,
          minSamples: 10,
          maxStdDevNt: 200.0, // Ambang ketat 200 nT
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Mulai rekam stasiun
    await tester.tap(find.text('Mulai Rekam Stasiun (2s)'));
    await tester.pump();

    // Pancarkan 15 sampel dengan variansi besar (+- 1000 nT)
    mockService.emitSamples(15, 45.0, 1.0);
    await tester.pump();

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Status harus REJECTED dan tombol Ulangi muncul
    expect(find.text('Status: REJECTED'), findsOneWidget);
    expect(find.text('Ulangi Rekam Stasiun (Data Bising)'), findsOneWidget);
    expect(find.text('Simpan Stasiun ke Database'), findsNothing);

    mockService.close();
    await testDb.close();
  });

  testWidgets(
      'StationSurveyScreen beralih ke NMEA Eksternal dan menerapkan koordinat RTK',
      (tester) async {
    final mockService = MockStationMagService();
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: StationSurveyScreen(
          service: mockService,
          database: testDb,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi opsi NMEA Eksternal
    expect(find.text('NMEA Eksternal'), findsOneWidget);
    await tester.tap(find.text('NMEA Eksternal'));
    await tester.pumpAndSettle();

    // Muncul tombol Input NMEA
    expect(find.text('Input NMEA'), findsOneWidget);
    await tester.tap(find.text('Input NMEA'));
    await tester.pumpAndSettle();

    // Dialog input NMEA muncul
    expect(find.text('Input Stream NMEA GNSS'), findsOneWidget);
    expect(find.text('Terapkan Koordinat'), findsOneWidget);

    // Tekan Terapkan Koordinat (menggunakan kalimat default GGA RTK)
    await tester.tap(find.text('Terapkan Koordinat'));
    await tester.pumpAndSettle();

    // Verifikasi indikator status fix dan pembaruan field Latitude / Longitude
    expect(find.textContaining('RTK Fix'), findsWidgets);
    expect(find.text('-6.891333'), findsOneWidget);
    expect(find.text('107.612000'), findsOneWidget);

    mockService.close();
    await testDb.close();
  });
}
