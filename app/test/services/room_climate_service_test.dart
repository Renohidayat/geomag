import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/services/room_climate_service.dart';

void main() {
  group('RoomClimateService Unit Tests', () {
    late RoomClimateService service;

    setUp(() {
      service = RoomClimateService();
    });

    test('Konversi Celsius dan Fahrenheit akurat bolak-balik', () {
      expect(RoomClimateService.celsiusToFahrenheit(0.0), closeTo(32.0, 1e-4));
      expect(RoomClimateService.celsiusToFahrenheit(100.0), closeTo(212.0, 1e-4));
      expect(RoomClimateService.celsiusToFahrenheit(25.0), closeTo(77.0, 1e-4));

      expect(RoomClimateService.fahrenheitToCelsius(32.0), closeTo(0.0, 1e-4));
      expect(RoomClimateService.fahrenheitToCelsius(212.0), closeTo(100.0, 1e-4));
      expect(RoomClimateService.fahrenheitToCelsius(77.0), closeTo(25.0, 1e-4));
    });

    test('estimateAmbientTemp menghitung disipasi termal idle dengan benar', () {
      // Baterai 31.4°C, tidak charging, layar hidup (+0.8), base delta 3.0 -> delta = 3.8 -> ambien = 27.6°C
      final temp = RoomClimateService.estimateAmbientTemp(
        batteryTempC: 31.4,
        isCharging: false,
        isScreenOn: true,
      );
      expect(temp, closeTo(27.6, 0.05));
    });

    test('estimateAmbientTemp memperhitungkan efek pengisian daya (Joule Heating Baterai)', () {
      // Baterai 34.0°C saat charging (+3.5) & layar hidup (+0.8) -> delta = 7.3 -> ambien = 26.7°C
      final temp = RoomClimateService.estimateAmbientTemp(
        batteryTempC: 34.0,
        isCharging: true,
        isScreenOn: true,
      );
      expect(temp, closeTo(26.7, 0.05));
    });

    test('estimateAmbientTemp menangani fallback sensor tak tersedia (<= 0)', () {
      final temp = RoomClimateService.estimateAmbientTemp(
        batteryTempC: -1.0,
        isCharging: false,
        isScreenOn: false,
        userOffsetC: 1.5,
      );
      expect(temp, closeTo(28.5, 0.05));
    });

    test('estimateHumidityPercent berada dalam rentang psikrometrik masuk akal', () {
      final rhComfortable = RoomClimateService.estimateHumidityPercent(
        ambientTempC: 25.0,
        pressureHpa: 1013.25,
      );
      expect(rhComfortable, greaterThanOrEqualTo(50.0));
      expect(rhComfortable, lessThanOrEqualTo(75.0));

      final rhHot = RoomClimateService.estimateHumidityPercent(
        ambientTempC: 35.0,
        pressureHpa: 1013.25,
      );
      expect(rhHot, lessThan(rhComfortable));
    });

    test('analyzeSample mendeteksi kondisi ruangan normal & sejuk', () {
      const normalSample = MagnetometerSample(
        timestampNs: 1000000,
        rawXMicroT: 18.0,
        rawYMicroT: -22.0,
        rawZMicroT: 32.0,
        biasXMicroT: 0.0,
        biasYMicroT: 0.0,
        biasZMicroT: 0.0,
        accuracy: 3,
        isUncalibrated: false,
        batteryTempC: 30.0,
        isCharging: false,
        isScreenOn: false,
        pressureHpa: 1013.0,
      );

      final result = service.analyzeSample(sample: normalSample);

      expect(result.isHotspotDetected, isFalse);
      expect(result.comfortLevel, RoomComfortLevel.comfortable);
      expect(result.statusTitle, contains('Suhu Nyaman'));
      expect(result.magneticEmfMicroT, lessThan(60.0));
      expect(result.ambientTempC, closeTo(27.0, 0.1));
    });

    test('analyzeSample mendeteksi titik hawa panas terfokus saat EMF > 60 µT (Joule heating kabel)', () {
      const hotspotSample = MagnetometerSample(
        timestampNs: 2000000,
        rawXMicroT: 50.0,
        rawYMicroT: 45.0,
        rawZMicroT: 40.0, // totalField > 75 µT
        biasXMicroT: 0.0,
        biasYMicroT: 0.0,
        biasZMicroT: 0.0,
        accuracy: 3,
        isUncalibrated: false,
        batteryTempC: 33.0,
        isCharging: false,
        isScreenOn: true,
        pressureHpa: 1011.5,
      );

      final result = service.analyzeSample(sample: hotspotSample);

      expect(result.isHotspotDetected, isTrue);
      expect(result.comfortLevel, RoomComfortLevel.hotspot);
      expect(result.statusTitle, contains('Hawa Panas Terfokus'));
      expect(result.statusDescription, contains('Joule Heating'));
      expect(result.magneticEmfMicroT, greaterThan(60.0));
    });

    test('analyzeSample menerapkan offset kalibrasi pengguna', () {
      const sample = MagnetometerSample(
        timestampNs: 3000000,
        rawXMicroT: 20.0,
        rawYMicroT: 20.0,
        rawZMicroT: 20.0,
        biasXMicroT: 0.0,
        biasYMicroT: 0.0,
        biasZMicroT: 0.0,
        accuracy: 3,
        isUncalibrated: false,
        batteryTempC: 30.0,
        isCharging: false,
        isScreenOn: false,
      );

      final baseResult = service.analyzeSample(sample: sample, userOffsetC: 0.0);
      final offsetResult = service.analyzeSample(sample: sample, userOffsetC: 2.0);

      expect(offsetResult.ambientTempC, closeTo(baseResult.ambientTempC + 2.0, 1e-4));
    });
  });
}
