import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/magnetometer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MagnetometerService', () {
    late MagnetometerService service;

    setUp(() {
      service = MagnetometerService();
    });

    test('getSensorInfo memanggil platform channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.geomag/magnetometer_method'),
        (MethodCall call) async {
          if (call.method == 'getSensorInfo') {
            return {
              'available': true,
              'isUncalibrated': true,
              'name': 'Test Sensor',
              'vendor': 'Test',
              'version': 1,
              'resolution': 0.15,
              'maxRange': 4912.0,
              'minDelay': 20000,
              'maxDelay': 500000,
              'power': 1.0,
            };
          }
          return null;
        },
      );

      final info = await service.getSensorInfo();

      expect(info.available, true);
      expect(info.isUncalibrated, true);
      expect(info.name, 'Test Sensor');
      expect(info.maxRateHz, closeTo(50.0, 0.01));
    });

    test('setTargetRate mengirim parameter yang benar', () async {
      int? receivedRate;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.geomag/magnetometer_method'),
        (MethodCall call) async {
          if (call.method == 'setTargetRate') {
            receivedRate = call.arguments['rateHz'] as int;
            return true;
          }
          return null;
        },
      );

      final result = await service.setTargetRate(100);

      expect(result, true);
      expect(receivedRate, 100);
    });

    test('statistik awal bernilai nol', () {
      expect(service.sampleCount, 0);
      expect(service.actualRateHz, 0);
      expect(service.jitterMs, 0);
    });

    test('resetStats mengosongkan semua statistik', () {
      service.resetStats();
      expect(service.sampleCount, 0);
      expect(service.actualRateHz, 0);
    });
  });
}
