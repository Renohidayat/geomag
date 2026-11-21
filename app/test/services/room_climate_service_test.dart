import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/weather_models.dart';
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

    test('Tabel 20 s.d. 45 °C: model monoton terhadap T_bat dan tidak terkunci di 27.0', () {
      double? prevEst;
      final outputs = <double, double>{};

      for (double t = 20.0; t <= 45.0; t += 1.0) {
        final est = RoomClimateService.estimateAmbientTemp(
          batteryTempC: t,
          isCharging: false,
          isScreenOn: true,
        );

        expect(est, isNotNull);
        outputs[t] = est!;

        if (prevEst != null) {
          // Harus monoton naik secara ketat terhadap suhu baterai
          expect(est, greaterThan(prevEst), reason: 'Suhu pada $t°C ($est) harus > pada ${t - 1}°C ($prevEst)');
        }
        prevEst = est;
      }

      // Verifikasi output bervariasi luas dan tidak macet di 27.0
      expect(outputs[20.0], closeTo(17.0, 0.1));
      expect(outputs[30.0], closeTo(27.0, 0.1));
      expect(outputs[35.0], closeTo(32.0, 0.1));
      expect(outputs[40.0], closeTo(37.0, 0.1));
      expect(outputs[45.0], closeTo(42.0, 0.1));
    });

    test('evaluateThermalState mengklasifikasikan status panas ponsel dengan tepat', () {
      expect(RoomClimateService.evaluateThermalState(30.0), DeviceThermalState.normal);
      expect(RoomClimateService.evaluateThermalState(33.0), DeviceThermalState.warm);
      expect(RoomClimateService.evaluateThermalState(35.5), DeviceThermalState.hot);
    });

    test('estimateAmbientTemp menangani fallback sensor tak tersedia (<= 0) dengan mengembalikan null', () {
      final temp = RoomClimateService.estimateAmbientTemp(
        batteryTempC: -1.0,
        isCharging: false,
        isScreenOn: false,
        userOffsetC: 1.5,
      );
      // Hapus fallback 27.0: sensor tidak tersedia harus bernilai null
      expect(temp, isNull);
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
      expect(result.ambientTempC, closeTo(32.5, 0.1));
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

    test('fetchOutdoorWeatherForLocation mengembalikan data dengan hourly forecast dan cache', () async {
      final cimalaka = AdmLocation(
        name: 'Cimalaka',
        district: 'Kec. Cimalaka',
        regency: 'Kab. Sumedang',
        province: 'Jawa Barat',
        latitude: -6.8122,
        longitude: 107.9482,
        adm4Code: '32.11.14.2001',
      );

      final weather = await service.fetchOutdoorWeatherForLocation(cimalaka);

      expect(weather.cityName, isNotEmpty);
      expect(weather.temperatureC, greaterThan(10.0));
      expect(weather.temperatureC, lessThan(45.0));
      expect(weather.sourceLabel, isNotEmpty);

      // Pemanggilan kedua harus mengembalikan objek yang sama dari cache
      final cachedWeather = await service.fetchOutdoorWeatherForLocation(cimalaka);
      expect(cachedWeather.temperatureC, weather.temperatureC);
      expect(cachedWeather.lastUpdated, weather.lastUpdated);
    });
  });
}
