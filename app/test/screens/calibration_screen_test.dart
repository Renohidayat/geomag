import 'dart:async';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/sensor_info.dart';
import 'package:geomag/screens/calibration_screen.dart';
import 'package:geomag/services/magnetometer_service.dart';

class MockCalibMagService extends MagnetometerService {
  final _controller = StreamController<MagnetometerSample>.broadcast();

  @override
  Stream<MagnetometerSample> get sampleStream => _controller.stream;

  @override
  Future<SensorInfo> getSensorInfo() async => const SensorInfo(
        available: true,
        isUncalibrated: true,
        name: 'Mock Test Magnetometer',
      );

  /// Memancarkan titik-titik berputar membentuk bola Fibonacci
  void emitRotatingSamples(int count, double radius) {
    final goldenRatio = (1.0 + sqrt(5.0)) / 2.0;

    for (var i = 0; i < count; i++) {
      final theta = 2.0 * pi * i / goldenRatio;
      final phi = acos(1.0 - 2.0 * (i + 0.5) / count);

      final x = radius * sin(phi) * cos(theta);
      final y = radius * sin(phi) * sin(theta);
      final z = radius * cos(phi);

      _controller.add(
        MagnetometerSample(
          timestampNs: 1000000000 + i * 20000000,
          rawXMicroT: x + 10.0, // offset buatan
          rawYMicroT: y - 5.0,
          rawZMicroT: z + 3.0,
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
      'CalibrationScreen menampilkan panduan bola, memperbarui cakupan orientasi, dan menyimpan profil kalibrasi',
      (tester) async {
    final mockService = MockCalibMagService();
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: CalibrationScreen(
          service: mockService,
          database: testDb,
          minSamples: 50, // threshold kecil untuk test cepat
          bRefMicroT: 45.0,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi UI awal
    expect(find.text('Kalibrasi Magnetometer'), findsOneWidget);
    expect(find.textContaining('Putar HP perlahan ke segala arah'), findsOneWidget);
    expect(find.textContaining('0.0% (0/18 sektor)'), findsOneWidget);
    expect(find.text('Sampel / Cakupan Belum Cukup'), findsOneWidget);

    // Pancarkan 80 sampel berputar
    mockService.emitRotatingSamples(80, 45.0);
    await tester.pumpAndSettle();

    // Verifikasi cakupan telah bertambah
    expect(find.textContaining('0.0% (0/18 sektor)'), findsNothing);
    expect(find.text('Hitung Kalibrasi Ellipsoid'), findsOneWidget);

    // Tekan tombol Hitung Kalibrasi
    final calcButtonFinder = find.text('Hitung Kalibrasi Ellipsoid');
    await tester.tap(calcButtonFinder);
    await tester.pumpAndSettle();

    // Verifikasi hasil kalibrasi muncul
    expect(find.text('Hasil Kalibrasi Ellipsoid'), findsOneWidget);
    expect(find.text('Residu Kalibrasi (RMSE):'), findsOneWidget);
    expect(find.text('Simpangan Baku Sebelum:'), findsOneWidget);
    expect(find.text('Simpangan Baku Sesudah:'), findsOneWidget);
    expect(find.text('Simpan Profil Kalibrasi ke Database'), findsOneWidget);

    // Simpan ke database
    final saveButtonFinder = find.text('Simpan Profil Kalibrasi ke Database');
    await tester.ensureVisible(saveButtonFinder);
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Tersimpan di Profil HP ✓'), findsOneWidget);

    // Verifikasi di database
    final latestProfile = await testDb.getLatestCalibrationProfile('default-device');
    expect(latestProfile, isNotNull);
    expect(latestProfile!.hardIronBxMicroT, closeTo(10.0, 1.0));
    expect(latestProfile.hardIronByMicroT, closeTo(-5.0, 1.0));
    expect(latestProfile.hardIronBzMicroT, closeTo(3.0, 1.0));
    expect(latestProfile.matrixA, isNotEmpty);

    // Uji tombol reset
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.textContaining('0.0% (0/18 sektor)'), findsOneWidget);
    expect(find.text('Hasil Kalibrasi Ellipsoid'), findsNothing);

    mockService.close();
    await testDb.close();
  });
}
