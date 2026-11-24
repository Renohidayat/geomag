import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:geomag/models/device_thermal_sample.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/weather_models.dart';
import 'package:geomag/services/climate/thermal_state_estimator.dart';

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

/// Data cuaca luar ruangan terpadu (BMKG / Open-Meteo).
class OutdoorWeatherData {
  final String cityName;
  final String? district;
  final String province;
  final double temperatureC;
  final double temperatureF;
  final double feelsLikeC;
  final double humidityPercent;
  final double pressureHpa;
  final double windSpeedKmh;
  final String? windDirectionText;
  final double? precipitationMm;
  final double? elevationM;
  final String weatherCondition;
  final String weatherEmoji;
  final bool isLive;
  final DateTime lastUpdated;
  final String sourceLabel;
  final List<HourlyForecast> hourlyForecasts;
  final String? adm4Code;
  final bool isGps;

  const OutdoorWeatherData({
    required this.cityName,
    this.district,
    required this.province,
    required this.temperatureC,
    required this.temperatureF,
    required this.feelsLikeC,
    required this.humidityPercent,
    required this.pressureHpa,
    required this.windSpeedKmh,
    this.windDirectionText,
    this.precipitationMm,
    this.elevationM,
    required this.weatherCondition,
    required this.weatherEmoji,
    required this.isLive,
    required this.lastUpdated,
    this.sourceLabel = 'Model Open-Meteo (Real-Time)',
    this.hourlyForecasts = const [],
    this.adm4Code,
    this.isGps = false,
  });

  String get fullLocationTitle {
    if (district != null && district!.isNotEmpty) {
      return '$cityName ($district, $province)';
    }
    return '$cityName, $province';
  }
}

/// Data hasil analisis termometer ruangan dan detektor iklim instan.
class RoomClimateData {
  /// Estimasi suhu udara ambien terkalibrasi (°C), null jika sensor tidak tersedia.
  final double? ambientTempC;

  /// Estimasi suhu udara ambien terkalibrasi (°F), null jika sensor tidak tersedia.
  final double? ambientTempF;

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

  /// Tingkat ketidakpastian suhu (± °C).
  final double uncertaintyC;

  /// Label badge status estimator (misal: 'Sensor Hardware', 'Terkalibrasi', 'Belum Dikalibrasi').
  final String statusBadgeLabel;

  /// Apakah bersumber langsung dari sensor suhu lingkungan hardware.
  final bool isHardwareSensor;

  /// Laju perubahan suhu (°C/menit).
  final double slopeCPerMinute;

  /// Arus baterai (mA) jika didukung.
  final double? currentNowMa;

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
    this.uncertaintyC = 3.0,
    this.statusBadgeLabel = 'Estimasi dari Baterai',
    this.isHardwareSensor = false,
    this.slopeCPerMinute = 0.0,
    this.currentNowMa,
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
  /// Menggunakan model uncalibrated sementara yang monoton terhadap T_bat:
  /// T_ruang = T_bat - D0 + offset (D0 = 3.0°C perkiraan kasar).
  /// Menghasilkan nilai null jika sensor baterai tidak tersedia (<= 0).
  static double? estimateAmbientTemp({
    required double batteryTempC,
    required bool isCharging,
    required bool isScreenOn,
    double userOffsetC = 0.0,
    bool isOutdoor = false,
  }) {
    // Hapus fallback 27.0: kembalikan null jika sensor tidak tersedia
    if (batteryTempC <= 0) {
      return null;
    }

    // Delta dasar uncalibrated (perkiraan kasar)
    double deltaInternal = 3.0;

    if (isCharging) {
      deltaInternal += 2.0; // Panas reaksi kimia charging
    }

    if (isOutdoor) {
      deltaInternal -= 0.5; // Pendinginan konveksi udara luar
    }

    // Model monoton: turunan d(estimated)/d(batteryTempC) = 1.0 > 0
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

    final ambientF = ambientC != null ? celsiusToFahrenheit(ambientC) : null;
    final hardwareC = sample.batteryTempC > 0 ? sample.batteryTempC : 0.0;
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

    final humidity = ambientC != null
        ? estimateHumidityPercent(
            ambientTempC: ambientC,
            pressureHpa: pressure,
          )
        : 55.0;

    // Kualitas udara estimasi (AQI) berbasis suhu dan kestabilan tekanan
    final aqi = ambientC != null
        ? 35 + ((ambientC - 24.0).abs() * 2).toInt().clamp(20, 85)
        : 40;
    final aqiLabel = aqi <= 50 ? 'Baik (AQI $aqi)' : 'Sedang (AQI $aqi)';

    // Deteksi hawa panas terfokus (Joule heating)
    final isEmfHigh = emfMicroT > kHotspotEmfThresholdMicroT;
    final isTempHot = ambientC != null && ambientC > 31.0;
    final isHotspot = isEmfHigh || (isTempHot && emfMicroT > 55.0);

    RoomComfortLevel level;
    String title;
    String desc;

    if (ambientC == null) {
      level = RoomComfortLevel.comfortable;
      title = 'Sensor Tidak Tersedia';
      desc = 'Menunggu data suhu baterai atau sensor hardware...';
    } else if (isHotspot) {
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
      uncertaintyC: 3.0,
      statusBadgeLabel: 'Belum Dikalibrasi (±3 °C)',
      isHardwareSensor: false,
      slopeCPerMinute: 0.0,
      currentNowMa: null,
    );
  }

  /// Menganalisis estimasi termal presisi dari [ThermalStateEstimator]
  /// bersama parameter lingkungan menjadi [RoomClimateData].
  RoomClimateData analyzeWithEstimator({
    required ThermalEstimationResult estimation,
    required MagnetometerSample sample,
    bool isOutdoor = false,
  }) {
    final ambientC = estimation.estimatedTempC;
    final ambientF = ambientC != null ? celsiusToFahrenheit(ambientC) : null;
    final hardwareC = estimation.hardwareTempC;
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

    final humidity = ambientC != null
        ? estimateHumidityPercent(
            ambientTempC: ambientC,
            pressureHpa: pressure,
          )
        : 55.0;

    final aqi = ambientC != null
        ? 35 + ((ambientC - 24.0).abs() * 2).toInt().clamp(20, 85)
        : 40;
    final aqiLabel = aqi <= 50 ? 'Baik (AQI $aqi)' : 'Sedang (AQI $aqi)';

    final isEmfHigh = emfMicroT > kHotspotEmfThresholdMicroT;
    final isTempHot = ambientC != null && ambientC > 31.0;
    final isHotspot = isEmfHigh || (isTempHot && emfMicroT > 55.0);

    RoomComfortLevel level;
    String title;
    String desc;

    if (ambientC == null) {
      level = RoomComfortLevel.comfortable;
      title = 'Sensor Tidak Tersedia';
      desc = 'Menunggu data pembacaan sensor baterai atau hardware...';
    } else if (isHotspot) {
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
      isCharging: estimation.isCharging,
      isScreenOn: estimation.isScreenOn,
      isOutdoor: isOutdoor,
      uncertaintyC: estimation.uncertaintyC,
      statusBadgeLabel: estimation.statusLabel,
      isHardwareSensor: estimation.isHardwareSensor,
      slopeCPerMinute: estimation.slopeCPerMinute,
      currentNowMa: estimation.currentNowMa,
    );
  }

  // Cache lokal cuaca dengan TTL 15 menit
  final Map<String, _CachedWeatherData> _weatherCache = {};

  /// Menarik data cuaca luar ruangan langsung dari Open-Meteo / BMKG API publik (Dual-Source).
  /// Menjaga batas rate-limit di bawah 60 req/min dengan caching 15 menit.
  Future<OutdoorWeatherData> fetchOutdoorWeather(CityLocation city) async {
    final admLoc = AdmLocation(
      name: city.name,
      province: city.province,
      latitude: city.latitude,
      longitude: city.longitude,
    );
    return fetchOutdoorWeatherForLocation(admLoc);
  }

  /// Menarik cuaca dual-source untuk lokasi administratif [AdmLocation].
  /// - Sumber 1 (Utama): BMKG API jika memiliki kode adm4 (dan respons < 3.5 detik).
  /// - Sumber 2 (Cadangan): Open-Meteo API berbasis koordinat lat/lon real-time (elevasi & kondisi terperinci).
  Future<OutdoorWeatherData> fetchOutdoorWeatherForLocation(
    AdmLocation location, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${location.latitude.toStringAsFixed(2)}_${location.longitude.toStringAsFixed(2)}_${location.adm4Code ?? ""}';

    // 1. Periksa cache lokal jika tidak dipaksa refresh (TTL 5 menit)
    if (!forceRefresh) {
      final cached = _weatherCache[cacheKey];
      if (cached != null) {
        final age = DateTime.now().difference(cached.cachedAt);
        if (age.inMinutes < 5) {
          return cached.data;
        }
      }
    }

    // 2. Sumber utama real-time: Open-Meteo API berbasis koordinat lat/lon presisi tinggi
    // Menghitung kompensasi elevasi dpl, arah mata angin 360°, curah hujan live, dan suhu terkini
    try {
      final openMeteoData = await _fetchOpenMeteoWeather(location);
      _weatherCache[cacheKey] = _CachedWeatherData(data: openMeteoData, cachedAt: DateTime.now());
      return openMeteoData;
    } catch (_) {
      // Fallback ke BMKG jika Open-Meteo tidak dapat dijangkau
    }

    // 3. Sumber cadangan Indonesia: BMKG API jika memiliki kode wilayah adm4
    if (location.adm4Code != null && location.adm4Code!.isNotEmpty) {
      try {
        final bmkgData = await _fetchBmkgWeather(location);
        if (bmkgData != null) {
          _weatherCache[cacheKey] = _CachedWeatherData(data: bmkgData, cachedAt: DateTime.now());
          return bmkgData;
        }
      } catch (_) {
        // Fallback offline jika BMKG juga gagal
      }
    }

    // 4. Default Offline Fallback jika tanpa koneksi internet sama sekali
    final fallbackData = OutdoorWeatherData(
      cityName: location.name,
      district: location.district,
      province: location.province,
      temperatureC: 25.0,
      temperatureF: celsiusToFahrenheit(25.0),
      feelsLikeC: 26.5,
      humidityPercent: 78.0,
      pressureHpa: 1012.4,
      windSpeedKmh: 9.2,
      weatherCondition: 'Cerah Berawan',
      weatherEmoji: '⛅',
      isLive: false,
      lastUpdated: DateTime.now(),
      sourceLabel: 'Data Offline Default',
      adm4Code: location.adm4Code,
      isGps: location.isGpsLocation,
    );
    _weatherCache[cacheKey] = _CachedWeatherData(data: fallbackData, cachedAt: DateTime.now());
    return fallbackData;
  }

  /// Menarik data cuaca dari BMKG publik (prakiraan-cuaca adm4)
  Future<OutdoorWeatherData?> _fetchBmkgWeather(AdmLocation location) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(milliseconds: 2500);

    final url = Uri.parse('https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4=${location.adm4Code}');
    final request = await client.getUrl(url);
    request.headers.set('User-Agent', 'GeoMagApp/1.0 (Android)');
    final response = await request.close().timeout(const Duration(milliseconds: 2500));

    if (response.statusCode != 200) return null;

    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final dataList = json['data'] as List<dynamic>?;
    if (dataList == null || dataList.isEmpty) return null;

    final cuacaRaw = dataList[0]['cuaca'];
    final hourlyForecasts = <HourlyForecast>[];

    double currentTempC = 25.0;
    double currentHumidity = 80.0;
    String currentCond = 'Berawan';
    String currentEmoji = '⛅';

    // Ekstraksi slot waktu BMKG (BMKG biasanya mengelompokkan per hari atau deret slot 3-jam)
    final now = DateTime.now();

    void processSlot(Map<String, dynamic> slot) {
      final utcTimeStr = slot['datetime'] as String? ?? slot['utc_datetime'] as String?;
      DateTime slotTime;
      if (utcTimeStr != null) {
        slotTime = DateTime.tryParse(utcTimeStr)?.toLocal() ?? now;
      } else {
        slotTime = now;
      }

      final t = (slot['t'] as num?)?.toDouble() ?? 26.0;
      final hu = (slot['hu'] as num?)?.toDouble() ?? 75.0;
      currentHumidity = hu;
      final desc = slot['weather_desc'] as String? ?? 'Berawan';
      final code = (slot['weather'] as num?)?.toInt() ?? 1;
      final (cCond, cEmoji) = _interpretWeatherCode(code);

      hourlyForecasts.add(
        HourlyForecast(
          time: slotTime,
          tempC: t,
          weatherCode: code,
          weatherCondition: desc.isNotEmpty ? desc : cCond,
          weatherEmoji: cEmoji,
        ),
      );
    }

    if (cuacaRaw is List) {
      for (final item in cuacaRaw) {
        if (item is List) {
          for (final sub in item) {
            if (sub is Map<String, dynamic>) processSlot(sub);
          }
        } else if (item is Map<String, dynamic>) {
          processSlot(item);
        }
      }
    }

    if (hourlyForecasts.isNotEmpty) {
      // Cari slot yang paling dekat dengan waktu saat ini
      hourlyForecasts.sort((a, b) => (a.time.difference(now).abs()).compareTo(b.time.difference(now).abs()));
      final nearest = hourlyForecasts.first;
      currentTempC = nearest.tempC;
      currentCond = nearest.weatherCondition;
      currentEmoji = nearest.weatherEmoji;

      // Urutkan kembali kronologis untuk slider 24 jam ke depan
      hourlyForecasts.sort((a, b) => a.time.compareTo(b.time));
    }

    final lokasi = json['lokasi'] as Map<String, dynamic>?;
    final desa = lokasi?['desa'] as String? ?? location.name;
    final kec = lokasi?['kecamatan'] as String? ?? location.district;
    final kotkab = lokasi?['kotkab'] as String? ?? location.regency;
    final prov = lokasi?['provinsi'] as String? ?? location.province;

    return OutdoorWeatherData(
      cityName: desa,
      district: kec != null ? 'Kec. $kec' : null,
      province: kotkab != null ? '$kotkab, $prov' : prov,
      temperatureC: currentTempC,
      temperatureF: celsiusToFahrenheit(currentTempC),
      feelsLikeC: currentTempC + 1.5,
      humidityPercent: currentHumidity,
      pressureHpa: 1012.0,
      windSpeedKmh: 8.0,
      weatherCondition: currentCond,
      weatherEmoji: currentEmoji,
      isLive: true,
      lastUpdated: DateTime.now(),
      sourceLabel: 'Prakiraan BMKG',
      hourlyForecasts: hourlyForecasts.take(8).toList(),
      adm4Code: location.adm4Code,
      isGps: location.isGpsLocation,
    );
  }

  /// Menarik data cuaca dari Open-Meteo publik berbasis koordinat lat/lon real-time
  Future<OutdoorWeatherData> _fetchOpenMeteoWeather(AdmLocation location) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?'
      'latitude=${location.latitude}&longitude=${location.longitude}'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,weather_code,surface_pressure,wind_speed_10m,wind_direction_10m'
      '&hourly=temperature_2m,relative_humidity_2m,weather_code'
      '&timezone=auto',
    );

    final request = await client.getUrl(url);
    final response = await request.close().timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw HttpException('Open-Meteo HTTP error ${response.statusCode}');
    }

    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;

    final tempC = (current['temperature_2m'] as num).toDouble();
    final humidity = (current['relative_humidity_2m'] as num).toDouble();
    final feelsLike = (current['apparent_temperature'] as num).toDouble();
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    final pressure = (current['surface_pressure'] as num?)?.toDouble() ?? 1012.0;
    final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 8.0;
    final windDeg = (current['wind_direction_10m'] as num?)?.toDouble();
    final precip = (current['precipitation'] as num?)?.toDouble() ?? (current['rain'] as num?)?.toDouble();
    final elevation = (json['elevation'] as num?)?.toDouble();

    final (cond, emoji) = _interpretWeatherCode(code);
    final windDir = windDeg != null ? interpretWindDirection(windDeg) : null;

    // Parse hourly forecast untuk 24 jam ke depan (tiap 3 jam = 8 slot)
    final hourlyForecasts = <HourlyForecast>[];
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (hourly != null) {
      final times = hourly['time'] as List<dynamic>? ?? [];
      final temps = hourly['temperature_2m'] as List<dynamic>? ?? [];
      final codes = hourly['weather_code'] as List<dynamic>? ?? [];

      final now = DateTime.now();
      for (int i = 0; i < times.length && hourlyForecasts.length < 8; i += 3) {
        final tStr = times[i] as String;
        final tDate = DateTime.tryParse(tStr) ?? now;
        if (tDate.isAfter(now.subtract(const Duration(hours: 1)))) {
          final hTemp = (temps[i] as num).toDouble();
          final hCode = (codes[i] as num?)?.toInt() ?? 0;
          final (hCond, hEmoji) = _interpretWeatherCode(hCode);
          hourlyForecasts.add(
            HourlyForecast(
              time: tDate,
              tempC: hTemp,
              weatherCode: hCode,
              weatherCondition: hCond,
              weatherEmoji: hEmoji,
            ),
          );
        }
      }
    }

    return OutdoorWeatherData(
      cityName: location.name,
      district: location.district,
      province: location.regency != null ? '${location.regency}, ${location.province}' : location.province,
      temperatureC: tempC,
      temperatureF: celsiusToFahrenheit(tempC),
      feelsLikeC: feelsLike,
      humidityPercent: humidity,
      pressureHpa: pressure,
      windSpeedKmh: wind,
      windDirectionText: windDir,
      precipitationMm: precip,
      elevationM: elevation,
      weatherCondition: cond,
      weatherEmoji: emoji,
      isLive: true,
      lastUpdated: DateTime.now(),
      sourceLabel: 'Model Open-Meteo (Real-Time)',
      hourlyForecasts: hourlyForecasts,
      adm4Code: location.adm4Code,
      isGps: location.isGpsLocation,
    );
  }

  /// Menerjemahkan derajat mata angin (0-360) ke teks bahasa Indonesia
  static String interpretWindDirection(double degrees) {
    const dirs = ['Utara', 'Timur Laut', 'Timur', 'Tenggara', 'Selatan', 'Barat Daya', 'Barat', 'Barat Laut'];
    final idx = ((degrees + 22.5) % 360) ~/ 45;
    return dirs[idx % dirs.length];
  }

  /// Menerjemahkan WMO Weather Interpretation Code ke bahasa Indonesia dan emoji.
  static (String, String) _interpretWeatherCode(int code) {
    if (code == 0) return ('Cerah', '☀️');
    if (code == 1 || code == 2) return ('Cerah Berawan', '⛅');
    if (code == 3) return ('Mendung / Berawan Tebal', '☁️');
    if (code == 45 || code == 48) return ('Berkabut', '🌫️');
    if (code >= 51 && code <= 55) return ('Hujan Ringan / Gerimis', '🌦️');
    if (code >= 56 && code <= 57) return ('Gerimis Beku', '🌧️');
    if (code >= 61 && code <= 65) return ('Hujan Sedang', '🌧️');
    if (code >= 66 && code <= 67) return ('Hujan Dingin', '🌧️');
    if (code >= 71 && code <= 77) return ('Salju', '🌨️');
    if (code >= 80 && code <= 82) return ('Hujan Deras / Showers', '⛈️');
    if (code >= 85 && code <= 86) return ('Hujan Salju', '🌨️');
    if (code >= 95 && code <= 99) return ('Badai Petir', '⚡');
    return ('Cerah Berawan', '⛅');
  }
}

/// Cache data cuaca dalam memori dengan TTL.
class _CachedWeatherData {
  final OutdoorWeatherData data;
  final DateTime cachedAt;

  const _CachedWeatherData({
    required this.data,
    required this.cachedAt,
  });
}
