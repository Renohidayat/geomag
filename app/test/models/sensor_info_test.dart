import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/models/sensor_info.dart';

void main() {
  group('SensorInfo', () {
    test('fromMap mem-parsing semua field', () {
      final data = <Object?, Object?>{
        'available': true,
        'isUncalibrated': true,
        'name': 'AK09918 Magnetometer',
        'vendor': 'AKM',
        'version': 1,
        'resolution': 0.15,
        'maxRange': 4912.0,
        'minDelay': 10000,
        'maxDelay': 500000,
        'power': 1.1,
      };

      final info = SensorInfo.fromMap(data);

      expect(info.available, true);
      expect(info.isUncalibrated, true);
      expect(info.name, 'AK09918 Magnetometer');
      expect(info.vendor, 'AKM');
      expect(info.version, 1);
      expect(info.resolutionMicroT, 0.15);
      expect(info.maxRangeMicroT, 4912.0);
      expect(info.minDelayUs, 10000);
      expect(info.maxDelayUs, 500000);
      expect(info.powerMa, 1.1);
    });

    test('maxRateHz menghitung dari minDelay', () {
      final info = SensorInfo(
        available: true,
        isUncalibrated: true,
        minDelayUs: 10000,
      );

      expect(info.maxRateHz, closeTo(100.0, 0.01));
    });

    test('maxRateHz null jika minDelay null', () {
      const info = SensorInfo(available: true, isUncalibrated: true);
      expect(info.maxRateHz, isNull);
    });

    test('maxRateHz null jika minDelay 0', () {
      const info = SensorInfo(
        available: true,
        isUncalibrated: true,
        minDelayUs: 0,
      );
      expect(info.maxRateHz, isNull);
    });

    test('fromMap menangani sensor tidak tersedia', () {
      final data = <Object?, Object?>{
        'available': false,
        'isUncalibrated': false,
        'name': null,
        'vendor': null,
        'version': null,
        'resolution': null,
        'maxRange': null,
        'minDelay': null,
        'maxDelay': null,
        'power': null,
      };

      final info = SensorInfo.fromMap(data);

      expect(info.available, false);
      expect(info.name, isNull);
      expect(info.maxRateHz, isNull);
    });
  });
}
