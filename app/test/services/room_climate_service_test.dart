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

    test('estimateAmbientTemp mencocokkan aplikasi rujukan: baterai 35.5°C menghasilkan suhu kamar 27.0°C', () {
      final temp = RoomClimateService.estimateAmbientTemp(
        batteryTempC: 35.5,
        isCharging: false,
        isScreenOn: true,
      );
      // 35.5 - (3.0 + 5.5) = 27.0°C
      expect(temp, closeTo(27.0, 0.05));
    });

    test('evaluateThermalState mengklasifikasikan status panas ponsel dengan tepat', () {
      expect(RoomClimateService.evaluateThermalState(30.0), DeviceThermalState.normal);
      expect(RoomClimateService.evaluateThermalState(33.0), DeviceThermalState.warm);
      expect(RoomClimateService.evaluateThermalState(35.5), DeviceThermalState.hot);
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
    });

    test('analyzeSample menyertakan peringatan saat perangkat panas', () {
      const hotSample = MagnetometerSample(
        timestampNs: 1000000,
        rawXMicroT: 18.0,
        rawYMicroT: -22.0,
        rawZMicroT: 32.0,
        biasXMicroT: 0.0,
        biasYMicroT: 0.0,
        biasZMicroT: 0.0,
        accuracy: 3,
        isUncalibrated: false,
        batteryTempC: 35.5,
        isCharging: false,
        isScreenOn: true,
        pressureHpa: 1013.0,
      );

      final result = service.analyzeSample(sample: hotSample);

      expect(result.thermalState, DeviceThermalState.hot);
      expect(result.thermalStateLabel, 'Panas');
      expect(result.warningMessage, contains('Perangkat Anda panas'));
      expect(result.ambientTempC, closeTo(27.0, 0.1));
    });

    test('popularCities memuat daftar kota utama Indonesia', () {
      expect(RoomClimateService.popularCities.length, greaterThanOrEqualTo(10));
      final names = RoomClimateService.popularCities.map((c) => c.name).toList();
      expect(names, contains('Jakarta Pusat'));
      expect(names, contains('Bandung'));
      expect(names, contains('Surabaya'));
    });

    test('fetchOutdoorWeather mengembalikan data cuaca valid', () async {
      final city = RoomClimateService.popularCities.first;
      final weather = await service.fetchOutdoorWeather(city);

      expect(weather.cityName, city.name);
      expect(weather.temperatureC, greaterThan(15.0));
      expect(weather.temperatureC, lessThan(45.0));
      expect(weather.weatherCondition, isNotEmpty);
      expect(weather.weatherEmoji, isNotEmpty);
    });
  });
}
