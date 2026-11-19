import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/sensor_info.dart';
import 'package:geomag/screens/settings_screen.dart';
import 'package:geomag/services/magnetometer_service.dart';

class MockSettingsMagService extends MagnetometerService {
  @override
  Future<SensorInfo> getSensorInfo() async => const SensorInfo(
        available: true,
        isUncalibrated: true,
        name: 'AK09918 Uncalibrated',
        vendor: 'Asahi Kasei',
        version: 1,
        resolutionMicroT: 0.15,
        maxRangeMicroT: 4912.0,
        minDelayUs: 20000,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockSettingsMagService mockService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    mockService = MockSettingsMagService();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('SettingsScreen menampilkan info sensor, satuan, dan statistik database',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          database: db,
          service: mockService,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi AppBar
    expect(find.text('Pengaturan'), findsOneWidget);

    // Verifikasi pilihan satuan
    expect(find.text('MikroTesla (µT) • Ramah Awam'), findsOneWidget);
    expect(find.text('NanoTesla (nT) • Geofisika'), findsOneWidget);

    // Verifikasi ambang deteksi
    expect(find.text('Ambang Batas Deteksi Anomali'), findsOneWidget);

    // Verifikasi info sensor setelah scroll
    final sensorText = find.text('AK09918 Uncalibrated');
    await tester.scrollUntilVisible(sensorText, 200);
    expect(sensorText, findsOneWidget);
    expect(find.text('GeoMag v1.0.0'), findsOneWidget);

    // Verifikasi tombol factory reset
    expect(find.text('Reset Seluruh Data Aplikasi (Mulai dari Nol)'), findsOneWidget);
  });

  testWidgets('SettingsScreen dapat melakukan dialog factory reset',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          database: db,
          service: mockService,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Ketuk tombol Reset Seluruh Data
    final resetBtn = find.text('Reset Seluruh Data Aplikasi (Mulai dari Nol)');
    await tester.ensureVisible(resetBtn);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    // Dialog konfirmasi harus muncul
    expect(find.text('Reset Seluruh Data?'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Ya, Hapus Semua'), findsOneWidget);

    // Batalkan
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Seluruh Data?'), findsNothing);
  });
}
