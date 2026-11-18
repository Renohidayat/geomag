import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/models/magnetometer_sample.dart';

void main() {
  group('MagnetometerSample', () {
    test('fromEventData mem-parsing semua field dengan benar', () {
      final data = <Object?, Object?>{
        'timestampNs': 1234567890000,
        'rawXMicroT': 25.5,
        'rawYMicroT': -10.3,
        'rawZMicroT': 42.1,
        'biasXMicroT': 1.0,
        'biasYMicroT': -0.5,
        'biasZMicroT': 0.3,
        'accuracy': 3,
        'isUncalibrated': true,
        'batteryTempC': 32.5,
        'isCharging': false,
        'isScreenOn': true,
      };

      final sample = MagnetometerSample.fromEventData(data);

      expect(sample.timestampNs, 1234567890000);
      expect(sample.rawXMicroT, 25.5);
      expect(sample.rawYMicroT, -10.3);
      expect(sample.rawZMicroT, 42.1);
      expect(sample.biasXMicroT, 1.0);
      expect(sample.biasYMicroT, -0.5);
      expect(sample.biasZMicroT, 0.3);
      expect(sample.accuracy, 3);
      expect(sample.isUncalibrated, true);
      expect(sample.batteryTempC, 32.5);
      expect(sample.isCharging, false);
      expect(sample.isScreenOn, true);
    });

    test('totalFieldMicroT menghitung magnitudo vektor dengan benar', () {
      final sample = MagnetometerSample(
        timestampNs: 0,
        rawXMicroT: 3.0,
        rawYMicroT: 4.0,
        rawZMicroT: 0.0,
        biasXMicroT: 0.0,
        biasYMicroT: 0.0,
        biasZMicroT: 0.0,
        accuracy: 3,
        isUncalibrated: true,
        batteryTempC: 25.0,
        isCharging: false,
        isScreenOn: true,
      );

      expect(sample.totalFieldMicroT, closeTo(5.0, 1e-10));
    });

    test('totalFieldMicroT 3D (3-4-5-√50 cek)', () {
      final sample = MagnetometerSample(
        timestampNs: 0,
        rawXMicroT: 3.0,
        rawYMicroT: 4.0,
        rawZMicroT: 5.0,
        biasXMicroT: 0.0,
        biasYMicroT: 0.0,
        biasZMicroT: 0.0,
        accuracy: 3,
        isUncalibrated: true,
        batteryTempC: 25.0,
        isCharging: false,
        isScreenOn: true,
      );

      expect(sample.totalFieldMicroT, closeTo(sqrt(50), 1e-10));
    });

    test('totalFieldNt mengonversi ke nanoTesla', () {
      final sample = MagnetometerSample(
        timestampNs: 0,
        rawXMicroT: 3.0,
        rawYMicroT: 4.0,
        rawZMicroT: 0.0,
        biasXMicroT: 0.0,
        biasYMicroT: 0.0,
        biasZMicroT: 0.0,
        accuracy: 3,
        isUncalibrated: true,
        batteryTempC: 25.0,
        isCharging: false,
        isScreenOn: true,
      );

      expect(sample.totalFieldNt, closeTo(5000.0, 1e-7));
    });

    test('fromEventData menangani int yang dikirim sebagai num', () {
      final data = <Object?, Object?>{
        'timestampNs': 999,
        'rawXMicroT': 1,
        'rawYMicroT': 2,
        'rawZMicroT': 3,
        'biasXMicroT': 0,
        'biasYMicroT': 0,
        'biasZMicroT': 0,
        'accuracy': 2,
        'isUncalibrated': false,
        'batteryTempC': -1,
        'isCharging': true,
        'isScreenOn': false,
      };

      final sample = MagnetometerSample.fromEventData(data);

      expect(sample.rawXMicroT, 1.0);
      expect(sample.rawYMicroT, 2.0);
      expect(sample.rawZMicroT, 3.0);
      expect(sample.isUncalibrated, false);
      expect(sample.isCharging, true);
    });

    test('toMap menghasilkan map yang bisa di-round-trip', () {
      final original = MagnetometerSample(
        timestampNs: 5000,
        rawXMicroT: 10.1,
        rawYMicroT: 20.2,
        rawZMicroT: 30.3,
        biasXMicroT: 0.1,
        biasYMicroT: 0.2,
        biasZMicroT: 0.3,
        accuracy: 1,
        isUncalibrated: true,
        batteryTempC: 28.0,
        isCharging: false,
        isScreenOn: true,
      );

      final map = original.toMap();

      expect(map['timestampNs'], 5000);
      expect(map['rawXMicroT'], 10.1);
      expect(map['rawYMicroT'], 20.2);
      expect(map['rawZMicroT'], 30.3);
      expect(map['biasXMicroT'], 0.1);
      expect(map['biasYMicroT'], 0.2);
      expect(map['biasZMicroT'], 0.3);
      expect(map['accuracy'], 1);
      expect(map['isUncalibrated'], true);
    });

    test('calibratedTotalFieldNt mengurangkan bias hard iron OS Android', () {
      final sample = MagnetometerSample(
        timestampNs: 1000,
        rawXMicroT: 53.0, // 53 - 50 = 3
        rawYMicroT: 84.0, // 84 - 80 = 4
        rawZMicroT: 20.0, // 20 - 20 = 0
        biasXMicroT: 50.0,
        biasYMicroT: 80.0,
        biasZMicroT: 20.0,
        accuracy: 3,
        isUncalibrated: true,
        batteryTempC: 30.0,
        isCharging: false,
        isScreenOn: true,
      );

      expect(sample.calibratedXMicroT, closeTo(3.0, 1e-10));
      expect(sample.calibratedYMicroT, closeTo(4.0, 1e-10));
      expect(sample.calibratedZMicroT, closeTo(0.0, 1e-10));
      expect(sample.calibratedTotalFieldMicroT, closeTo(5.0, 1e-10));
      expect(sample.calibratedTotalFieldNt, closeTo(5000.0, 1e-10));
    });
  });
}
