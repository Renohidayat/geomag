import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/sensor_info.dart';
import 'package:geomag/screens/home_screen.dart';
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

  testWidgets('HomeScreen menampilkan info sensor dan tombol rekam',
      (tester) async {
    final mockService = MockMagnetometerService();
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(service: mockService, database: testDb),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('GeoMag - Survei Magnetik'), findsOneWidget);
    expect(find.text('Info Sensor'), findsOneWidget);
    expect(find.text('AK09918 Uncalibrated'), findsOneWidget);
    expect(find.text('Uncalibrated'), findsOneWidget);
    expect(find.text('Mulai Rekam'), findsOneWidget);

    mockService.close();
    await testDb.close();
  });

  testWidgets(
      'HomeScreen menampilkan data real-time, menyimpan sampel, dan menampilkan tombol ekspor CSV',
      (tester) async {
    final mockService = MockMagnetometerService();
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(service: mockService, database: testDb),
      ),
    );

    await tester.pumpAndSettle();

    // Tekan tombol Mulai Rekam
    await tester.tap(find.text('Mulai Rekam'));
    await tester.pump();

    expect(find.textContaining('Berhenti'), findsOneWidget);

    // Pancarkan 1 sampel
    mockService.emitSample(
      const MagnetometerSample(
        timestampNs: 1000000000,
        rawXMicroT: 25.5,
        rawYMicroT: -12.3,
        rawZMicroT: 41.2,
        biasXMicroT: 0.0,
        biasYMicroT: 0.0,
        biasZMicroT: 0.0,
        accuracy: 3,
        isUncalibrated: true,
        batteryTempC: 31.5,
        isCharging: false,
        isScreenOn: true,
      ),
    );

    await tester.pump();

    // Verifikasi data muncul di layar
    expect(find.text('Data Medan Magnetik (Real-time)'), findsOneWidget);
    expect(find.text('25.50 µT'), findsOneWidget);
    expect(find.text('-12.30 µT'), findsOneWidget);
    expect(find.text('41.20 µT'), findsOneWidget);
    expect(find.text('Tinggi (3)'), findsOneWidget);
    expect(find.text('31.5 °C'), findsOneWidget);
    expect(find.text('Baterai (Aman ✓)'), findsOneWidget);

    // Tekan Berhenti
    await tester.tap(find.textContaining('Berhenti'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Mulai Rekam'), findsOneWidget);
    expect(find.text('Ekspor Data Stasiun ke CSV'), findsOneWidget);

    mockService.close();
    await testDb.close();
  });

  testWidgets(
      'HomeScreen memiliki kartu navigasi Termometer Suhu Ruangan & Udara',
      (tester) async {
    final mockService = MockMagnetometerService();
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(service: mockService, database: testDb),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Termometer Suhu Ruangan & Udara'), findsOneWidget);

    mockService.close();
    await testDb.close();
  });
}
