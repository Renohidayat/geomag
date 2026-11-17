import 'dart:async';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/sensor_info.dart';
import 'package:geomag/screens/noise_test_screen.dart';
import 'package:geomag/services/magnetometer_service.dart';

class MockNoiseMagService extends MagnetometerService {
  final _controller = StreamController<MagnetometerSample>.broadcast();

  @override
  Stream<MagnetometerSample> get sampleStream => _controller.stream;

  @override
  Future<SensorInfo> getSensorInfo() async => const SensorInfo(
        available: true,
        isUncalibrated: true,
        name: 'Test Magnetometer',
      );

  void emitSamples(int count, double baseMicroT) {
    for (var i = 0; i < count; i++) {
      final noise = sin(i * 1.5) * 0.15 + (i * 0.03);
      _controller.add(
        MagnetometerSample(
          timestampNs: 1000000000 + i * 20000000,
          rawXMicroT: baseMicroT + noise,
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
      'NoiseTestScreen menampilkan instruksi, menjalankan uji noise, dan menyimpan ke database',
      (tester) async {
    final mockService = MockNoiseMagService();
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: NoiseTestScreen(
          service: mockService,
          database: testDb,
          testDurationSeconds: 2, // 2 detik untuk tes cepat
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Uji Lantai Noise HP'), findsOneWidget);
    expect(find.text('Protokol Uji Noise'), findsOneWidget);
    expect(find.textContaining('Mulai Uji Lantai Noise'), findsOneWidget);

    // Tekan Mulai Uji
    await tester.tap(find.textContaining('Mulai Uji Lantai Noise'));
    await tester.pump();

    // Pancarkan 15 sampel medan magnetik
    mockService.emitSamples(15, 45.0);
    await tester.pump();

    // Fast-forward 2 detik sampai countdown selesai
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Verifikasi hasil Allan Deviation muncul
    expect(find.text('Hasil Pengukuran Allan Deviation'), findsOneWidget);
    expect(find.text('Lantai Noise Terukur:'), findsOneWidget);
    expect(find.text('Simpan Lantai Noise ke Profil HP'), findsOneWidget);

    // Simpan ke profil HP
    final saveButtonFinder = find.text('Simpan Lantai Noise ke Profil HP');
    await tester.ensureVisible(saveButtonFinder);
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Tersimpan di Profil HP ✓'), findsOneWidget);

    // Verifikasi di database
    final device = await testDb.getDevice('default-device');
    expect(device, isNotNull);
    expect(device!.noiseFloorNt, isNotNull);
    expect(device.noiseFloorNt!, greaterThan(0.0));

    mockService.close();
    await testDb.close();
  });
}
