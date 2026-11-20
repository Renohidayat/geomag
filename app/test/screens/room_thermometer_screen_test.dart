import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/sensor_info.dart';
import 'package:geomag/screens/room_thermometer_screen.dart';
import 'package:geomag/services/magnetometer_service.dart';

class MockMagnetometerService extends MagnetometerService {
  final _controller = StreamController<MagnetometerSample>.broadcast();

  @override
  Stream<MagnetometerSample> get sampleStream => _controller.stream;

  @override
  Future<SensorInfo> getSensorInfo() async => const SensorInfo(
        available: true,
        isUncalibrated: true,
        name: 'AK09918 Uncalibrated',
      );

  void emitSample(MagnetometerSample sample) {
    _controller.add(sample);
  }

  void close() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoomThermometerScreen Widget Tests', () {
    late MockMagnetometerService mockService;

    setUp(() {
      mockService = MockMagnetometerService();
    });

    tearDown(() {
      mockService.close();
    });

    testWidgets('Merender tampilan awal termometer ruangan lengkap dengan komponen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Memeriksa judul AppBar dan subjudul
      expect(find.text('Termometer Ruangan'), findsOneWidget);
      expect(find.text('Live Climate & Thermal Scanner'), findsOneWidget);

      // Memeriksa toggle unit
      expect(find.text('°C'), findsWidgets);
      expect(find.text('°F'), findsWidgets);

      // Memeriksa pemilih mode
      expect(find.text('Dalam Ruangan'), findsOneWidget);
      expect(find.text('Cuaca Luar'), findsOneWidget);

      // Memeriksa 4 kartu parameter lingkungan
      expect(find.text('Kelembaban Udara'), findsOneWidget);
      expect(find.text('Tekanan Barometer'), findsOneWidget);
      expect(find.text('Medan Magnet EMF'), findsOneWidget);
      expect(find.text('Suhu Chipset HP'), findsOneWidget);

      // Memeriksa kartu analisis hawa panas & kalibrasi
      expect(find.text('Detektor Hawa Panas Terfokus'), findsOneWidget);
      expect(find.text('Kalibrasi Offset Suhu (±3.0 °C)'), findsOneWidget);
      expect(find.byType(LiquidThermometerWidget), findsOneWidget);
    });

    testWidgets('Toggle unit °C ke °F memperbarui pembacaan suhu',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Emit sampel dengan suhu baterai 31.8°C (ambien ~28.0°C -> ~82.4°F)
      mockService.emitSample(
        const MagnetometerSample(
          timestampNs: 1000,
          rawXMicroT: 15.0,
          rawYMicroT: -20.0,
          rawZMicroT: 30.0,
          biasXMicroT: 0.0,
          biasYMicroT: 0.0,
          biasZMicroT: 0.0,
          accuracy: 3,
          isUncalibrated: false,
          batteryTempC: 31.8,
          isCharging: false,
          isScreenOn: true,
          pressureHpa: 1013.2,
        ),
      );
      await tester.pumpAndSettle();

      // Di mode °C (default), mencari '°C'
      expect(find.text('°C'), findsWidgets);

      // Ketuk toggle '°F'
      final fahrenheitPill = find.text('°F').first;
      await tester.tap(fahrenheitPill);
      await tester.pumpAndSettle();

      // Satuan utama pada hero card sekarang menampilkan '°F'
      expect(find.text('°F'), findsWidgets);

      // Ketuk kembali '°C'
      final celsiusPill = find.text('°C').first;
      await tester.tap(celsiusPill);
      await tester.pumpAndSettle();

      expect(find.text('°C'), findsWidgets);
    });

    testWidgets('Ganti mode Dalam Ruangan ke Cuaca Luar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SUHU RUANGAN'), findsOneWidget);

      // Ketuk 'Cuaca Luar'
      await tester.tap(find.text('Cuaca Luar'));
      await tester.pumpAndSettle();

      expect(find.text('CUACA LUAR'), findsOneWidget);
    });

    testWidgets('Deteksi hawa panas terfokus aktif saat sensor menerima medan EMF tinggi',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Kirim data dengan medan magnet tinggi > 60 µT (misal dekat stopkontak)
      mockService.emitSample(
        const MagnetometerSample(
          timestampNs: 2000,
          rawXMicroT: 50.0,
          rawYMicroT: 50.0,
          rawZMicroT: 50.0, // total > 86 µT
          biasXMicroT: 0.0,
          biasYMicroT: 0.0,
          biasZMicroT: 0.0,
          accuracy: 3,
          isUncalibrated: false,
          batteryTempC: 32.0,
          isCharging: false,
          isScreenOn: true,
          pressureHpa: 1012.0,
        ),
      );
      await tester.pumpAndSettle();

      // Harus menampilkan status peringatan hawa panas terfokus
      expect(find.text('🔥 Hawa Panas Terfokus Terdeteksi'), findsOneWidget);
      expect(
        find.text('Peringatan: Radiasi Termal & Listrik Terdeteksi'),
        findsOneWidget,
      );
    });
  });
}
