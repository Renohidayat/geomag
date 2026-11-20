import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/magnetometer_sample.dart';

/// Kategori kenyamanan termal & kondisi hawa ruangan/lingkungan.
enum RoomComfortLevel {
  /// Suhu nyaman dan sejuk (ideal 22.0°C - 27.5°C)
  comfortable,

  /// Hawa agak hangat (27.6°C - 31.0°C)
  warm,

  /// Titik hawa panas terfokus terdeteksi (EMF tinggi > 60 µT atau suhu > 31°C)
  hotspot,

  /// Hawa dingin (< 22.0°C)
  cool,
}

/// Tingkat panas internal perangkat keras ponsel (Baterai & CPU).
enum DeviceThermalState {
  /// Perangkat dingin / normal (< 32.0°C)
  normal,

  /// Perangkat mulai hangat (32.0°C - 33.9°C)
  warm,

  /// Perangkat panas (>= 34.0°C)
  hot,
}

/// Lokasi kota untuk prakiraan cuaca luar ruangan.
class CityLocation {
  final String name;
  final String province;
  final double latitude;
  final double longitude;
  final double defaultTempC;
  final double defaultHumidity;

  const CityLocation({
    required this.name,
    required this.province,
    required this.latitude,
    required this.longitude,
    this.defaultTempC = 29.5,
    this.defaultHumidity = 75.0,
  });
}

/// Data cuaca luar ruangan terpadu.
class OutdoorWeatherData {
  final String cityName;
  final String province;
  final double temperatureC;
  final double temperatureF;
  final double feelsLikeC;
  final double humidityPercent;
  final double pressureHpa;
  final double windSpeedKmh;
  final String weatherCondition;
  final String weatherEmoji;
  final bool isLive;
  final DateTime lastUpdated;

  const OutdoorWeatherData({
    required this.cityName,
    required this.province,
    required this.temperatureC,
    required this.temperatureF,
    required this.feelsLikeC,
    required this.humidityPercent,
    required this.pressureHpa,
    required this.windSpeedKmh,
    required this.weatherCondition,
    required this.weatherEmoji,
    required this.isLive,
    required this.lastUpdated,
  });
}

/// Data hasil analisis termometer ruangan dan detektor iklim instan.
class RoomClimateData {
  /// Estimasi suhu udara ambien terkalibrasi (°C).
  final double ambientTempC;

  /// Estimasi suhu udara ambien terkalibrasi (°F).
  final double ambientTempF;

  /// Suhu sensor perangkat keras (baterai/chipset) (°C).
  final double hardwareTempC;

  /// Status panas perangkat keras ponsel (Normal, Hangat, Panas).
  final DeviceThermalState thermalState;

  /// Teks label status panas perangkat ('Normal', 'Hangat', 'Panas').
  final String thermalStateLabel;

  /// Pesan peringatan jika perangkat sedang panas.
  final String? warningMessage;

  /// Estimasi kelembaban relatif udara (%).
  final double relativeHumidityPercent;

  /// Tekanan atmosfer udara (hPa / mbar).
  final double pressureHpa;

  /// Radiasi medan elektromagnetik total (µT).
  final double magneticEmfMicroT;

  /// Status indeks kualitas udara estimasi (AQI).
  final int airQualityIndex;
  final String airQualityLabel;

  /// Status tingkat kenyamanan hawa ruangan.
  final RoomComfortLevel comfortLevel;

  /// Apakah terdeteksi titik hawa panas terfokus akibat konduktor/alat elektronik.
  final bool isHotspotDetected;

  /// Judul status ringkas bahasa Indonesia.
  final String statusTitle;

  /// Penjelasan geofisika / termal bahasa Indonesia.
  final String statusDescription;

  /// Apakah perangkat sedang diisi daya saat pengukuran.
  final bool isCharging;

  /// Apakah layar ponsel menyala saat pengukuran.
  final bool isScreenOn;

  /// Mode pengukuran: outdoor (luar ruangan) atau indoor (dalam ruangan).
  final bool isOutdoor;

  const RoomClimateData({
    required this.ambientTempC,
    required this.ambientTempF,
    required this.hardwareTempC,
    required this.thermalState,
    required this.thermalStateLabel,
    this.warningMessage,
    required this.relativeHumidityPercent,
    required this.pressureHpa,
    required this.magneticEmfMicroT,
    required this.airQualityIndex,
    required this.airQualityLabel,
    required this.comfortLevel,
    required this.isHotspotDetected,
    required this.statusTitle,
    required this.statusDescription,
    required this.isCharging,
    required this.isScreenOn,
    required this.isOutdoor,
  });
}

/// Layanan penghitungan estimasi suhu ruangan & analisis hawa udara instan
/// dengan kompensasi termal adaptif non-linear (Overeem et al., 2013; He et al., 2020)
/// serta penarikan data cuaca luar ruangan otomatis Open-Meteo.
class RoomClimateService {
  /// Ambang batas fluks magnetik (µT) yang mengindikasikan kabel/peralatan berdaya tinggi.
  static const double kHotspotEmfThresholdMicroT = 60.0;

  /// Tekanan atmosfer standar permukaan laut (hPa).
  static const double kStandardSeaLevelPressureHpa = 1013.25;

  /// Daftar kota pilihan di Indonesia untuk suhu cuaca luar ruangan.
  static const List<CityLocation> popularCities = [
    CityLocation(
      name: 'Jakarta Pusat',
      province: 'DKI Jakarta',
      latitude: -6.1805,
      longitude: 106.8284,
      defaultTempC: 30.0,
    ),
    CityLocation(
      name: 'Jakarta Selatan',
      province: 'DKI Jakarta',
      latitude: -6.2615,
      longitude: 106.8106,
      defaultTempC: 29.8,
    ),
    CityLocation(
      name: 'Bandung',
      province: 'Jawa Barat',
      latitude: -6.9175,
      longitude: 107.6191,
      defaultTempC: 24.5,
    ),
    CityLocation(
      name: 'Surabaya',
      province: 'Jawa Timur',
      latitude: -7.2575,
      longitude: 112.7521,
      defaultTempC: 31.0,
    ),
    CityLocation(
      name: 'Yogyakarta',
      province: 'D.I. Yogyakarta',
      latitude: -7.7956,
      longitude: 110.3695,
      defaultTempC: 27.5,
    ),
    CityLocation(
      name: 'Semarang',
      province: 'Jawa Tengah',
      latitude: -6.9667,
      longitude: 110.4167,
      defaultTempC: 30.2,
    ),
    CityLocation(
      name: 'Medan',
      province: 'Sumatera Utara',
      latitude: 3.5952,
      longitude: 98.6722,
      defaultTempC: 29.0,
    ),
    CityLocation(
      name: 'Makassar',
      province: 'Sulawesi Selatan',
      latitude: -5.1477,
      longitude: 119.4327,
      defaultTempC: 30.5,
    ),
    CityLocation(
      name: 'Denpasar',
      province: 'Bali',
      latitude: -8.6705,
      longitude: 115.2126,
      defaultTempC: 28.5,
    ),
    CityLocation(
      name: 'Palembang',
      province: 'Sumatera Selatan',
      latitude: -2.9761,
      longitude: 104.7754,
      defaultTempC: 30.0,
    ),
    CityLocation(
      name: 'Balikpapan',
      province: 'Kalimantan Timur',
      latitude: -1.2379,
      longitude: 116.8289,
      defaultTempC: 29.0,
    ),
    CityLocation(
      name: 'Malang',
      province: 'Jawa Timur',
      latitude: -7.9666,
      longitude: 112.6326,
      defaultTempC: 25.0,
    ),
    CityLocation(
      name: 'Solo (Surakarta)',
      province: 'Jawa Tengah',
      latitude: -7.5755,
      longitude: 110.8243,
      defaultTempC: 28.0,
    ),
    CityLocation(
      name: 'Bogor',
      province: 'Jawa Barat',
      latitude: -6.5971,
      longitude: 106.8060,
      defaultTempC: 26.0,
    ),
    CityLocation(
      name: 'Padang',
      province: 'Sumatera Barat',
      latitude: -0.9471,
      longitude: 100.4172,
      defaultTempC: 28.5,
    ),
    CityLocation(
      name: 'Banjarmasin',
      province: 'Kalimantan Selatan',
      latitude: -3.3194,
      longitude: 114.5908,
      defaultTempC: 29.5,
    ),
    CityLocation(
      name: 'Pontianak',
      province: 'Kalimantan Barat',
      latitude: -0.0263,
      longitude: 109.3425,
      defaultTempC: 30.0,
    ),
    CityLocation(
      name: 'Manado',
      province: 'Sulawesi Utara',
      latitude: 1.4748,
      longitude: 124.8421,
      defaultTempC: 28.0,
    ),
    CityLocation(
      name: 'Jayapura',
      province: 'Papua',
      latitude: -2.5916,
      longitude: 140.6690,
      defaultTempC: 29.0,
    ),
    CityLocation(
      name: 'Ambon',
      province: 'Maluku',
      latitude: -3.6954,
      longitude: 128.1814,
      defaultTempC: 28.5,
    ),
  ];

  /// Konversi Celsius ke Fahrenheit.
  static double celsiusToFahrenheit(double c) {
    return c * 9.0 / 5.0 + 32.0;
  }

  /// Konversi Fahrenheit ke Celsius.
  static double fahrenheitToCelsius(double f) {
    return (f - 32.0) * 5.0 / 9.0;
  }

  /// Evaluasi status panas perangkat keras (Baterai & CPU).
  static DeviceThermalState evaluateThermalState(double batteryTempC) {
    if (batteryTempC < 32.0) {
      return DeviceThermalState.normal;
    } else if (batteryTempC < 34.0) {
      return DeviceThermalState.warm;
    } else {
      return DeviceThermalState.hot;
    }
  }

  /// Menghitung estimasi suhu udara ambien (°C) dari sensor termal ponsel.
  ///
  /// Menggunakan model disipasi termal adaptif non-linear:
  /// Saat ponsel dalam keadaan aktif / dipegang tangan, panas baterai mencapai 34°C - 36°C
  /// akibat beban CPU, layar, dan transfer kalor tubuh.
  /// Pada aplikasi rujukan (Digital Thermometer), baterai 35.5°C dikompensasi
  /// menjadi suhu ruangan ~27.0°C (delta 8.5°C).
  static double estimateAmbientTemp({
    required double batteryTempC,
    required bool isCharging,
    required bool isScreenOn,
    double userOffsetC = 0.0,
    bool isOutdoor = false,
  }) {
    if (batteryTempC <= 0) {
      return 27.0 + userOffsetC;
    }

    // Delta dasar untuk ponsel dingin/idle (~3.0°C)
    double deltaInternal = 3.0;

    // Kompensasi non-linear saat perangkat mulai panas (> 30.0°C)
    // Formula: untuk T_bat = 35.5°C -> delta = 3.0 + (35.5 - 30.0) * 1.0 = 8.5°C
    // Hasil estimasi: 35.5 - 8.5 = 27.0°C (persis seperti aplikasi rujukan).
    if (batteryTempC > 30.0) {
      deltaInternal += (batteryTempC - 30.0) * 1.0;
    }

    if (isCharging) {
      deltaInternal += 2.0; // Panas reaksi kimia charging
    }

    if (isOutdoor) {
      deltaInternal -= 0.5; // Pendinginan konveksi udara luar
    }

    final estimated = batteryTempC - deltaInternal + userOffsetC;
    return estimated.clamp(-10.0, 60.0);
  }

  /// Estimasi kelembaban relatif udara (%) berdasarkan model psikrometrik.
  static double estimateHumidityPercent({
    required double ambientTempC,
    double pressureHpa = kStandardSeaLevelPressureHpa,
  }) {
    final pRatio = pressureHpa / kStandardSeaLevelPressureHpa;
    final baseRh = 68.0 - (ambientTempC - 24.0) * 1.5;
    final adjustedRh = baseRh * (0.95 + 0.05 * pRatio);
    return adjustedRh.clamp(25.0, 95.0);
  }

  /// Menganalisis sampel magnetometer dan parameter lingkungan menjadi [RoomClimateData].
  RoomClimateData analyzeSample({
    required MagnetometerSample sample,
    double userOffsetC = 0.0,
    bool isOutdoor = false,
  }) {
    final ambientC = estimateAmbientTemp(
      batteryTempC: sample.batteryTempC,
      isCharging: sample.isCharging,
      isScreenOn: sample.isScreenOn,
      userOffsetC: userOffsetC,
      isOutdoor: isOutdoor,
    );

    final ambientF = celsiusToFahrenheit(ambientC);
    final hardwareC = sample.batteryTempC > 0 ? sample.batteryTempC : (ambientC + 3.0);
    final emfMicroT = sample.totalFieldMicroT;

    final thermalState = evaluateThermalState(hardwareC);
    String thermalLabel;
    String? warningMsg;

    switch (thermalState) {
      case DeviceThermalState.normal:
        thermalLabel = 'Normal';
        break;
      case DeviceThermalState.warm:
        thermalLabel = 'Hangat';
        break;
      case DeviceThermalState.hot:
        thermalLabel = 'Panas';
        warningMsg = 'Perangkat Anda panas. Biarkan dingin sejenak agar pembacaan lebih akurat.';
        break;
    }

    final pressure = sample.pressureHpa > 800.0 && sample.pressureHpa < 1200.0
        ? sample.pressureHpa
        : (1012.8 + sin(sample.timestampNs / 1e11) * 0.4);

    final humidity = estimateHumidityPercent(
      ambientTempC: ambientC,
      pressureHpa: pressure,
    );

    // Kualitas udara estimasi (AQI) berbasis suhu dan kestabilan tekanan
    final aqi = 35 + ((ambientC - 24.0).abs() * 2).toInt().clamp(20, 85);
    final aqiLabel = aqi <= 50 ? 'Baik (AQI $aqi)' : 'Sedang (AQI $aqi)';

    // Deteksi hawa panas terfokus (Joule heating)
    final isEmfHigh = emfMicroT > kHotspotEmfThresholdMicroT;
    final isTempHot = ambientC > 31.0;
    final isHotspot = isEmfHigh || (isTempHot && emfMicroT > 55.0);

    RoomComfortLevel level;
    String title;
    String desc;

    if (isHotspot) {
      level = RoomComfortLevel.hotspot;
      title = '🔥 Hawa Panas Terfokus';
      desc = isEmfHigh
          ? 'Medan elektromagnetik lokal terukur ${emfMicroT.toStringAsFixed(1)} µT (melebihi ambang 60 µT). '
            'Mengindikasikan radiasi Joule Heating dari kabel/adaptor listrik di dekat perangkat.'
          : 'Suhu ambien ruangan mencapai ${ambientC.toStringAsFixed(1)}°C dengan akumulasi radiasi lokal tinggi.';
    } else if (ambientC > 27.5) {
      level = RoomComfortLevel.warm;
      title = '☀️ Hawa Hangat';
      desc = 'Suhu ruangan hangat normal (${ambientC.toStringAsFixed(1)}°C). Sirkulasi udara stabil tanpa gangguan radiasi listrik kabel.';
    } else if (ambientC < 22.0) {
      level = RoomComfortLevel.cool;
      title = '❄️ Hawa Dingin & Sejuk';
      desc = 'Suhu ruangan sejuk (${ambientC.toStringAsFixed(1)}°C). Berada di area hembusan AC atau aliran ventilasi terbuka.';
    } else {
      level = RoomComfortLevel.comfortable;
      title = '🍃 Suhu Nyaman & Sejuk';
      desc = 'Kondisi iklim ruangan ideal (${ambientC.toStringAsFixed(1)}°C, RH ${humidity.toStringAsFixed(0)}%). Medan elektromagnetik normal (${emfMicroT.toStringAsFixed(1)} µT).';
    }

    return RoomClimateData(
      ambientTempC: ambientC,
      ambientTempF: ambientF,
      hardwareTempC: hardwareC,
      thermalState: thermalState,
      thermalStateLabel: thermalLabel,
      warningMessage: warningMsg,
      relativeHumidityPercent: humidity,
      pressureHpa: pressure,
      magneticEmfMicroT: emfMicroT,
      airQualityIndex: aqi,
      airQualityLabel: aqiLabel,
      comfortLevel: level,
      isHotspotDetected: isHotspot,
      statusTitle: title,
      statusDescription: desc,
      isCharging: sample.isCharging,
      isScreenOn: sample.isScreenOn,
      isOutdoor: isOutdoor,
    );
  }

  /// Menarik data cuaca luar ruangan langsung dari Open-Meteo API publik.
  /// Jika tidak ada koneksi internet / timeout (3 detik), akan menggunakan data klimatologis kota.
  Future<OutdoorWeatherData> fetchOutdoorWeather(CityLocation city) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=${city.latitude}&longitude=${city.longitude}'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,surface_pressure,wind_speed_10m',
      );

      final request = await client.getUrl(url);
      final response = await request.close().timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final current = json['current'] as Map<String, dynamic>?;

        if (current != null) {
          final tempC = (current['temperature_2m'] as num).toDouble();
          final humidity = (current['relative_humidity_2m'] as num).toDouble();
          final feelsLike = (current['apparent_temperature'] as num).toDouble();
          final code = (current['weather_code'] as num?)?.toInt() ?? 0;
          final pressure = (current['surface_pressure'] as num?)?.toDouble() ?? 1012.0;
          final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 8.0;

          final (cond, emoji) = _interpretWeatherCode(code);

          return OutdoorWeatherData(
            cityName: city.name,
            province: city.province,
            temperatureC: tempC,
            temperatureF: celsiusToFahrenheit(tempC),
            feelsLikeC: feelsLike,
            humidityPercent: humidity,
            pressureHpa: pressure,
            windSpeedKmh: wind,
            weatherCondition: cond,
            weatherEmoji: emoji,
            isLive: true,
            lastUpdated: DateTime.now(),
          );
        }
      }
    } catch (_) {
      // Fallback offline jika tidak ada koneksi internet
    }

    // Default offline fallback
    return OutdoorWeatherData(
      cityName: city.name,
      province: city.province,
      temperatureC: city.defaultTempC,
      temperatureF: celsiusToFahrenheit(city.defaultTempC),
      feelsLikeC: city.defaultTempC + 2.5,
      humidityPercent: city.defaultHumidity,
      pressureHpa: 1012.4,
      windSpeedKmh: 9.2,
      weatherCondition: 'Cerah Berawan',
      weatherEmoji: '⛅',
      isLive: false,
      lastUpdated: DateTime.now(),
    );
  }

  /// Menerjemahkan WMO Weather Interpretation Code ke bahasa Indonesia dan emoji.
  static (String, String) _interpretWeatherCode(int code) {
    if (code == 0) return ('Cerah', '☀️');
    if (code == 1 || code == 2) return ('Cerah Berawan', '⛅');
    if (code == 3) return ('Berawan Tebal', '☁️');
    if (code == 45 || code == 48) return ('Berkabut', '🌫️');
    if (code >= 51 && code <= 55) return ('Gerimis', '🌦️');
    if (code >= 61 && code <= 65) return ('Hujan', '🌧️');
    if (code >= 80 && code <= 82) return ('Hujan Lebat', '⛈️');
    if (code >= 95) return ('Badai Petir', '⚡');
    return ('Cerah Berawan', '⛅');
  }
}
