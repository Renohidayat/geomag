import 'dart:convert';

/// Keadaan termal perangkat untuk pemilihan model kompensasi fisik.
enum ThermalState {
  /// Sedang mengumpulkan data awal (jendela < 3 menit belum terpenuhi).
  collectingData,

  /// Sensor hardware ambient fisik tersedia (Sensor.TYPE_AMBIENT_TEMPERATURE).
  hardwareAmbient,

  /// Perangkat sedang diisi daya atau arus beban tinggi (panas internal mendominasi).
  chargingOrHeavyLoad,

  /// Periode transisi/pendinginan setelah beban berat selesai.
  coolingAfterLoad,

  /// Suhu baterai sedang bergerak aktif mendingin atau menghangat (hukum Newton berlaku).
  coolingOrWarming,

  /// Ponsel aktif dengan layar menyala, tidak charging, beban stabil/rendah.
  activeLight,

  /// Ponsel diam/idle dengan layar mati/redup dan suhu stabil.
  steadyIdle,
}

/// Sampel pembacaan status termal dan daya perangkat.
class DeviceThermalSample {
  final int timestampNs;
  final double batteryTempC;
  final bool isCharging;
  final bool isScreenOn;
  final double? currentNowMa;
  final bool hasAmbientHardwareSensor;
  final double? ambientTempHardwareC;
  final double pressureHpa;

  const DeviceThermalSample({
    required this.timestampNs,
    required this.batteryTempC,
    required this.isCharging,
    required this.isScreenOn,
    this.currentNowMa,
    this.hasAmbientHardwareSensor = false,
    this.ambientTempHardwareC,
    this.pressureHpa = -1.0,
  });

  /// Timestamp dalam detik.
  double get timestampSeconds => timestampNs / 1e9;

  /// Apakah suhu baterai valid (> 0 °C).
  bool get isBatteryTempValid => batteryTempC > 0.0;

  factory DeviceThermalSample.fromMap(Map<Object?, Object?> map) {
    return DeviceThermalSample(
      timestampNs: (map['timestampNs'] as num?)?.toInt() ?? 0,
      batteryTempC: (map['batteryTempC'] as num?)?.toDouble() ?? -1.0,
      isCharging: map['isCharging'] as bool? ?? false,
      isScreenOn: map['isScreenOn'] as bool? ?? true,
      currentNowMa: (map['currentNowMa'] as num?)?.toDouble(),
      hasAmbientHardwareSensor: map['hasAmbientHardwareSensor'] as bool? ?? false,
      ambientTempHardwareC: (map['ambientTempHardwareC'] as num?)?.toDouble(),
      pressureHpa: (map['pressureHpa'] as num?)?.toDouble() ?? -1.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestampNs': timestampNs,
      'batteryTempC': batteryTempC,
      'isCharging': isCharging,
      'isScreenOn': isScreenOn,
      'currentNowMa': currentNowMa,
      'hasAmbientHardwareSensor': hasAmbientHardwareSensor,
      'ambientTempHardwareC': ambientTempHardwareC,
      'pressureHpa': pressureHpa,
    };
  }
}

/// Profil parameter kalibrasi termal per-perangkat.
class ThermalCalibrationProfile {
  final int version;
  final String deviceId;
  final double a;
  final double b;
  final double tau;
  final double d0;
  final double rmse;
  final double r2;
  final DateTime? calibratedAt;
  final int durationMinutes;

  const ThermalCalibrationProfile({
    this.version = 1,
    this.deviceId = 'default',
    this.a = 1.0,
    this.b = -3.0,
    this.tau = 240.0,
    this.d0 = 3.0,
    this.rmse = 0.0,
    this.r2 = 1.0,
    this.calibratedAt,
    this.durationMinutes = 15,
  });

  bool get isCalibrated => calibratedAt != null;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'deviceId': deviceId,
      'a': a,
      'b': b,
      'tau': tau,
      'd0': d0,
      'rmse': rmse,
      'r2': r2,
      'calibratedAt': calibratedAt?.toIso8601String(),
      'durationMinutes': durationMinutes,
    };
  }

  factory ThermalCalibrationProfile.fromJson(Map<String, dynamic> json) {
    return ThermalCalibrationProfile(
      version: json['version'] as int? ?? 1,
      deviceId: json['deviceId'] as String? ?? 'default',
      a: (json['a'] as num?)?.toDouble() ?? 1.0,
      b: (json['b'] as num?)?.toDouble() ?? -3.0,
      tau: (json['tau'] as num?)?.toDouble() ?? 240.0,
      d0: (json['d0'] as num?)?.toDouble() ?? 3.0,
      rmse: (json['rmse'] as num?)?.toDouble() ?? 0.0,
      r2: (json['r2'] as num?)?.toDouble() ?? 1.0,
      calibratedAt: json['calibratedAt'] != null
          ? DateTime.tryParse(json['calibratedAt'] as String)
          : null,
      durationMinutes: json['durationMinutes'] as int? ?? 15,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ThermalCalibrationProfile.fromJsonString(String source) =>
      ThermalCalibrationProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// Hasil estimasi suhu ruangan lengkap dengan status dan ketidakpastian.
class ThermalEstimationResult {
  final double? estimatedTempC;
  final ThermalState state;
  final double slopeCPerMinute;
  final double uncertaintyC;
  final String statusLabel;
  final bool isCalibrated;
  final String? dataCollectionProgress;
  final double hardwareTempC;
  final double rawBatteryTempC;
  final bool isCharging;
  final bool isScreenOn;
  final double? currentNowMa;
  final bool isHardwareSensor;

  const ThermalEstimationResult({
    required this.estimatedTempC,
    required this.state,
    required this.slopeCPerMinute,
    required this.uncertaintyC,
    required this.statusLabel,
    required this.isCalibrated,
    this.dataCollectionProgress,
    required this.hardwareTempC,
    required this.rawBatteryTempC,
    required this.isCharging,
    required this.isScreenOn,
    this.currentNowMa,
    this.isHardwareSensor = false,
  });
}
