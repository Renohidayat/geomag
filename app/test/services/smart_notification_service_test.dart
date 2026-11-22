import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/smart_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartNotificationService Unit Tests', () {
    late SmartNotificationService service;
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.geomag/magnetometer_method'),
        (MethodCall call) async {
          methodCalls.add(call);
          if (call.method == 'initNotificationChannels') {
            return true;
          }
          if (call.method == 'showNotification') {
            return true;
          }
          return null;
        },
      );

      service = SmartNotificationService();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.geomag/magnetometer_method'),
        null,
      );
    });

    test('Inisialisasi channel notifikasi native memanggil initNotificationChannels', () async {
      await service.initChannels();
      expect(methodCalls.any((c) => c.method == 'initNotificationChannels'), isTrue);
    });

    test('Suhu sekitar normal (< 35 °C) tidak memicu notifikasi', () {
      final eval = service.evaluateThermal(
        ambientTempC: 28.5,
        batteryTempC: 32.0,
        isCharging: false,
        currentNowMa: -250.0,
      );

      expect(eval.status, ThermalAlertStatus.normal);
      expect(eval.isTriggered, isFalse);
    });

    test('Hawa sekitar nyata panas (>= 35 °C) dengan arus rendah memicu notifikasi', () {
      final eval = service.evaluateThermal(
        ambientTempC: 36.2,
        batteryTempC: 38.0,
        isCharging: false,
        currentNowMa: -300.0, // Arus rendah santai
      );

      expect(eval.status, ThermalAlertStatus.alertTriggered);
      expect(eval.isTriggered, isTrue);
      expect(eval.notificationTitle, contains('36.2 °C'));
      expect(eval.notificationBody, contains('sangat panas'));
    });

    test('Panas mesin akibat main game (arus > 600 mA) MENAHAN notifikasi (suppressedGaming)', () {
      // Skenario: Di luar sejuk (23 °C), main game berat bikin baterai 39 °C dan arus -1450 mA
      final eval = service.evaluateThermal(
        ambientTempC: 36.5, // Walau estimasi sempat terdorong
        batteryTempC: 39.5,
        isCharging: false,
        currentNowMa: -1450.0, // Indikasi jelas gaming / CPU load tinggi
      );

      expect(eval.status, ThermalAlertStatus.suppressedGaming);
      expect(eval.isTriggered, isFalse);
      expect(eval.message, contains('game/beban CPU berat'));
    });

    test('Panas akibat pengisian daya (charging) MENAHAN notifikasi (suppressedCharging)', () {
      final eval = service.evaluateThermal(
        ambientTempC: 37.0,
        batteryTempC: 40.0,
        isCharging: true, // Sedang fast charging
        currentNowMa: 2200.0,
      );

      expect(eval.status, ThermalAlertStatus.suppressedCharging);
      expect(eval.isTriggered, isFalse);
      expect(eval.message, contains('charging'));
    });

    test('Cooldown mencegah spam notifikasi hawa panas dalam rentang 15 menit', () async {
      final t0 = DateTime(2026, 11, 22, 10, 0, 0);

      // Pemicu pertama berhasil
      final triggered = await service.checkAndDispatchThermalAlert(
        ambientTempC: 36.0,
        batteryTempC: 38.0,
        isCharging: false,
        currentNowMa: -200.0,
        currentTime: t0,
      );
      expect(triggered, isTrue);
      expect(service.lastThermalAlertTime, equals(t0));

      // 5 menit kemudian masih panas -> Tertahan cooldown
      final t1 = t0.add(const Duration(minutes: 5));
      final eval1 = service.evaluateThermal(
        ambientTempC: 36.5,
        batteryTempC: 38.5,
        isCharging: false,
        currentNowMa: -200.0,
        currentTime: t1,
      );
      expect(eval1.status, ThermalAlertStatus.suppressedCooldown);
      expect(eval1.isTriggered, isFalse);

      // 16 menit kemudian -> Cooldown selesai, memicu kembali
      final t2 = t0.add(const Duration(minutes: 16));
      final eval2 = service.evaluateThermal(
        ambientTempC: 36.5,
        batteryTempC: 38.5,
        isCharging: false,
        currentNowMa: -200.0,
        currentTime: t2,
      );
      expect(eval2.status, ThermalAlertStatus.alertTriggered);
      expect(eval2.isTriggered, isTrue);
    });

    test('Mematikan notifikasi di config menghasilkan status disabled', () {
      service.updateConfig(service.config.copyWith(isThermalAlertEnabled: false));

      final eval = service.evaluateThermal(
        ambientTempC: 38.0,
        batteryTempC: 40.0,
        isCharging: false,
        currentNowMa: -200.0,
      );

      expect(eval.status, ThermalAlertStatus.disabled);
      expect(eval.isTriggered, isFalse);
    });

    test('Medan magnet wajar (< 100 µT) tidak memicu notifikasi magnetik', () {
      final eval = service.evaluateMagnetic(totalFieldMicroT: 44.5); // Medan bumi Indonesia
      expect(eval.status, MagneticAlertStatus.normal);
      expect(eval.isTriggered, isFalse);
    });

    test('Medan magnet kritis (>= 100 µT) memicu notifikasi darurat', () {
      final eval = service.evaluateMagnetic(totalFieldMicroT: 115.8);
      expect(eval.status, MagneticAlertStatus.alertTriggered);
      expect(eval.isTriggered, isTrue);
      expect(eval.notificationTitle, contains('115.8 µT'));
      expect(eval.notificationBody, contains('sumber magnet'));
    });

    test('Cooldown mencegah spam notifikasi magnetik dalam rentang 5 menit', () async {
      final t0 = DateTime(2026, 11, 22, 10, 0, 0);

      final triggered = await service.checkAndDispatchMagneticAlert(
        totalFieldMicroT: 120.0,
        currentTime: t0,
      );
      expect(triggered, isTrue);

      final t1 = t0.add(const Duration(minutes: 2));
      final eval = service.evaluateMagnetic(
        totalFieldMicroT: 130.0,
        currentTime: t1,
      );
      expect(eval.status, MagneticAlertStatus.suppressedCooldown);
      expect(eval.isTriggered, isFalse);
    });

    test('Uji coba notifikasi (triggerTestNotification) berhasil mengirim notifikasi native', () async {
      final successThermal = await service.triggerTestNotification(isThermal: true);
      expect(successThermal, isTrue);

      final successMagnetic = await service.triggerTestNotification(isThermal: false);
      expect(successMagnetic, isTrue);

      expect(methodCalls.where((c) => c.method == 'showNotification').length, equals(2));
    });
  });
}
