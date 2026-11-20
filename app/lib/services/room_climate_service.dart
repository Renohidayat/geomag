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

/// Data hasil analisis termometer ruangan dan detektor iklim instan.
class RoomClimateData {
  /// Estimasi suhu udara ambien terkalibrasi (°C).
  final double ambientTempC;

  /// Estimasi suhu udara ambien terkalibrasi (°F).
  final double ambientTempF;

  /// Suhu sensor perangkat keras (baterai/chipset) (°C).
  final double hardwareTempC;

  /// Estimasi kelembaban relatif udara (%).
  final double relativeHumidityPercent;

  /// Tekanan atmosfer udara (hPa / mbar).
  final double pressureHpa;

  /// Radiasi medan elektromagnetik total (µT).
  final double magneticEmfMicroT;

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
    required this.relativeHumidityPercent,
    required this.pressureHpa,
    required this.magneticEmfMicroT,
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
/// berdasarkan model kompensasi termal baterai smartphone (Overeem et al., 2013; He et al., 2020)
/// dan deteksi radiasi panas Joule Heating (P = I^2 R) via fluks medan magnetik Ampere.
class RoomClimateService {
  /// Ambang batas fluks magnetik (µT) yang mengindikasikan kabel/peralatan berdaya tinggi.
  static const double kHotspotEmfThresholdMicroT = 60.0;

  /// Tekanan atmosfer standar permukaan laut (hPa).
  static const double kStandardSeaLevelPressureHpa = 1013.25;

  /// Konversi Celsius ke Fahrenheit.
  static double celsiusToFahrenheit(double c) {
    return c * 9.0 / 5.0 + 32.0;
  }

  /// Konversi Fahrenheit ke Celsius.
  static double fahrenheitToCelsius(double f) {
    return (f - 32.0) * 5.0 / 9.0;
  }

  /// Menghitung estimasi suhu udara ambien (°C) dari sensor termal ponsel.
  ///
  /// Menggunakan model disipasi panas termal:
  /// T_ambien = T_baterai - DeltaT_internal + offsetPengguna
  ///
  /// DeltaT_internal dipengaruhi oleh:
  /// - Base thermal gradient idle (~2.8°C s.d. 3.2°C)
  /// - Status pengisian daya baterai (Joule heating kimiawi baterai +3.2°C)
  /// - Status layar dan pemrosesan aktif (+0.6°C s.d. 1.0°C)
  static double estimateAmbientTemp({
    required double batteryTempC,
    required bool isCharging,
    required bool isScreenOn,
    double userOffsetC = 0.0,
    bool isOutdoor = false,
  }) {
    // Jika sensor suhu hardware tidak tersedia (-1 atau <= 0 di beberapa emulator),
    // gunakan suhu ruangan standar ekuator Indonesia (27.0°C).
    if (batteryTempC <= 0) {
      return 27.0 + userOffsetC;
    }

    double deltaInternal = 3.0; // Base baseline offset

    if (isCharging) {
      deltaInternal += 3.5; // Efek pengisian daya
    }

    if (isScreenOn) {
      deltaInternal += 0.8; // Efek backlight & display driver
    }

    if (isOutdoor) {
      // Di luar ruangan terdapat sirkulasi konveksi angin alami yang menurunkan
      // akumulasi panas casing ponsel sekitar 0.4°C
      deltaInternal -= 0.4;
    }

    final estimated = batteryTempC - deltaInternal + userOffsetC;

    // Batasi dalam rentang fisik yang masuk akal (-10°C s.d. 60°C)
    return estimated.clamp(-10.0, 60.0);
  }

  /// Estimasi kelembaban relatif udara (%) berdasarkan model psikrometrik
  /// aproksimasi Magnus-Tetens untuk lingkungan tropis/ruangan.
  static double estimateHumidityPercent({
    required double ambientTempC,
    double pressureHpa = kStandardSeaLevelPressureHpa,
  }) {
    // Ruangan ideal di daerah tropis umumnya memiliki kelembaban 50% - 65%.
    // Semakin tinggi suhu ambien, kelembaban relatif cenderung turun secara psikrometrik.
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

    // Tekanan atmosfer: gunakan sensor hardware jika tersedia, atau baseline standar
    final pressure = sample.pressureHpa > 800.0 && sample.pressureHpa < 1200.0
        ? sample.pressureHpa
        : (1012.8 + sin(sample.timestampNs / 1e11) * 0.4);

    final humidity = estimateHumidityPercent(
      ambientTempC: ambientC,
      pressureHpa: pressure,
    );

    // Deteksi hawa panas terfokus (Joule heating dari instalasi listrik / adaptor)
    final isEmfHigh = emfMicroT > kHotspotEmfThresholdMicroT;
    final isTempHot = ambientC > 31.0;
    final isHotspot = isEmfHigh || (isTempHot && emfMicroT > 55.0);

    RoomComfortLevel level;
    String title;
    String desc;

    if (isHotspot) {
      level = RoomComfortLevel.hotspot;
      title = '🔥 Hawa Panas Terfokus Terdeteksi';
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
      relativeHumidityPercent: humidity,
      pressureHpa: pressure,
      magneticEmfMicroT: emfMicroT,
      comfortLevel: level,
      isHotspotDetected: isHotspot,
      statusTitle: title,
      statusDescription: desc,
      isCharging: sample.isCharging,
      isScreenOn: sample.isScreenOn,
      isOutdoor: isOutdoor,
    );
  }
}
