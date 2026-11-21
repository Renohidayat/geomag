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

    testWidgets('Merender tampilan awal termometer mirip rujukan dengan Dial Meter dan kartu metrik',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Memeriksa judul AppBar dan ikon mahkota
      expect(find.text('Termometer'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);

      // Memeriksa toggle unit
      expect(find.text('°C'), findsWidgets);
      expect(find.text('°F'), findsWidgets);

      // Memeriksa dial card 'Suhu Sekitar'
      expect(find.text('Suhu Sekitar'), findsWidgets);
      expect(find.text('Analisis Suhu'), findsOneWidget);

      // Memeriksa 4 kartu metrik utama
      expect(find.text('Panas Perangkat'), findsOneWidget);
      expect(find.text('Baterai'), findsOneWidget);
      expect(find.text('Kualitas Udara'), findsOneWidget);
      expect(find.text('Radar Cuaca'), findsOneWidget);

      // Memeriksa Bottom Navigation Bar
      expect(find.text('Cuaca Wilayah'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);
    });

    testWidgets('Banner peringatan muncul saat suhu baterai tinggi (Panas)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Emit sampel dengan suhu baterai 35.5°C (status Panas)
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
          batteryTempC: 35.5,
          isCharging: false,
          isScreenOn: true,
          pressureHpa: 1013.2,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Perangkat Anda panas. Biarkan dingin sejenak agar pembacaan lebih akurat.'),
        findsOneWidget,
      );
      expect(find.text('Panas'), findsWidgets);
    });

    testWidgets('Toggle unit °C ke °F memperbarui pembacaan satuan',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Ketuk toggle '°F'
      final fahrenheitPill = find.text('°F').first;
      await tester.tap(fahrenheitPill);
      await tester.pumpAndSettle();

      expect(find.text('°F'), findsWidgets);

      // Ketuk kembali '°C'
      final celsiusPill = find.text('°C').first;
      await tester.tap(celsiusPill);
      await tester.pumpAndSettle();

      expect(find.text('°C'), findsWidgets);
    });

    testWidgets('Pindah ke tab Cuaca Wilayah dan membuka pemilih wilayah adm4/GPS',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Pindah ke tab Cuaca Wilayah
      await tester.tap(find.text('Cuaca Wilayah'));
      await tester.pumpAndSettle();

      // Memeriksa elemen lokasi bawaan (Cimalaka, Sumedang)
      expect(find.text('Cimalaka'), findsWidgets);
      expect(find.text('Cari'), findsOneWidget);

      // Ketuk tombol Cari
      await tester.tap(find.text('Cari'));
      await tester.pumpAndSettle();

      // Memeriksa modal dialog daftar wilayah muncul
      expect(find.text('Pilih Wilayah Cuaca'), findsOneWidget);
      expect(find.text('Gunakan Lokasi GPS Saya Saat Ini'), findsOneWidget);
      expect(find.text('Sumedang Utara'), findsOneWidget);

      // Pilih Sumedang Utara
      await tester.tap(find.text('Sumedang Utara'));
      await tester.pumpAndSettle();

      expect(find.text('Sumedang Utara'), findsWidgets);
    });

    testWidgets('Pindah ke tab Pengaturan dan menampilkan kalibrasi termal serta atribusi',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Pindah ke tab Pengaturan
      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();

      expect(find.text('Kalibrasi Termal Fisik HP'), findsOneWidget);
      expect(find.text('Kalibrasi Offset Suhu (±3.0 °C)'), findsOneWidget);
      expect(find.text('Sumber Data & Atribusi'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('Membuka modal Analisis Suhu', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Tekan tombol Analisis Suhu
      await tester.ensureVisible(find.text('Analisis Suhu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analisis Suhu'));
      await tester.pumpAndSettle();

      expect(find.text('Rincian Analisis Termal & Iklim'), findsOneWidget);
      expect(find.text('Suhu Baterai / Hardware'), findsOneWidget);
      expect(find.text('Suhu Sekitar Terestimasi'), findsOneWidget);
    });

    testWidgets('Banner Penyesuaian Otomatis Cuaca muncul dan dapat diselaraskan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomThermometerScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Memeriksa banner patokan cuaca muncul
      expect(find.textContaining('Patokan Cuaca'), findsOneWidget);

      // Mengetuk tombol Sinkron/Sesuaikan
      final syncButton = find.byIcon(Icons.sync_rounded).first;
      await tester.ensureVisible(syncButton);
      await tester.pumpAndSettle();
      await tester.tap(syncButton);
      await tester.pumpAndSettle();

      // SnackBar konfirmasi muncul
      expect(find.textContaining('berhasil diselaraskan'), findsOneWidget);
    });
  });
}
