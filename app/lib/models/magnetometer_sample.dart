import 'dart:math';

/// Data satu sampel magnetometer dari sensor Android.
class MagnetometerSample {
  /// Timestamp event dari sensor (nanodetik, monotonic clock Android).
  final int timestampNs;

  /// Nilai mentah sumbu X (mikroTesla).
  final double rawXMicroT;

  /// Nilai mentah sumbu Y (mikroTesla).
  final double rawYMicroT;

  /// Nilai mentah sumbu Z (mikroTesla).
  final double rawZMicroT;

  /// Estimasi bias hard iron OS sumbu X (mikroTesla).
  final double biasXMicroT;

  /// Estimasi bias hard iron OS sumbu Y (mikroTesla).
  final double biasYMicroT;

  /// Estimasi bias hard iron OS sumbu Z (mikroTesla).
  final double biasZMicroT;

  /// Akurasi sensor (0–3, dari Android SensorManager).
  final int accuracy;

  /// Apakah data berasal dari sensor uncalibrated.
  final bool isUncalibrated;

  /// Suhu baterai sebagai proksi suhu perangkat (°C), -1 jika tidak tersedia.
  final double batteryTempC;

  /// Apakah perangkat sedang diisi daya.
  final bool isCharging;

  /// Apakah layar menyala.
  final bool isScreenOn;

  const MagnetometerSample({
    required this.timestampNs,
    required this.rawXMicroT,
    required this.rawYMicroT,
    required this.rawZMicroT,
    required this.biasXMicroT,
    required this.biasYMicroT,
    required this.biasZMicroT,
    required this.accuracy,
    required this.isUncalibrated,
    required this.batteryTempC,
    required this.isCharging,
    required this.isScreenOn,
  });

  /// Total field (magnitudo vektor mentah) dalam mikroTesla.
  double get totalFieldMicroT {
    return sqrt(
      rawXMicroT * rawXMicroT +
      rawYMicroT * rawYMicroT +
      rawZMicroT * rawZMicroT,
    );
  }

  /// Total field dalam nanoTesla.
  double get totalFieldNt => totalFieldMicroT * 1000.0;

  /// Vektor X terkoreksi estimasi bias hard-iron OS Android (mikroTesla).
  double get calibratedXMicroT => rawXMicroT - biasXMicroT;

  /// Vektor Y terkoreksi estimasi bias hard-iron OS Android (mikroTesla).
  double get calibratedYMicroT => rawYMicroT - biasYMicroT;

  /// Vektor Z terkoreksi estimasi bias hard-iron OS Android (mikroTesla).
  double get calibratedZMicroT => rawZMicroT - biasZMicroT;

  /// Magnitudo total field terkoreksi estimasi bias hard-iron OS Android (mikroTesla).
  double get calibratedTotalFieldMicroT {
    final cx = calibratedXMicroT;
    final cy = calibratedYMicroT;
    final cz = calibratedZMicroT;
    return sqrt(cx * cx + cy * cy + cz * cz);
  }

  /// Total field terkoreksi estimasi bias hard-iron OS Android (nanoTesla).
  double get calibratedTotalFieldNt => calibratedTotalFieldMicroT * 1000.0;

  /// Membuat instance dari Map yang dikirim EventChannel Kotlin.
  factory MagnetometerSample.fromEventData(Map<Object?, Object?> data) {
    return MagnetometerSample(
      timestampNs: data['timestampNs'] as int,
      rawXMicroT: (data['rawXMicroT'] as num).toDouble(),
      rawYMicroT: (data['rawYMicroT'] as num).toDouble(),
      rawZMicroT: (data['rawZMicroT'] as num).toDouble(),
      biasXMicroT: (data['biasXMicroT'] as num).toDouble(),
      biasYMicroT: (data['biasYMicroT'] as num).toDouble(),
      biasZMicroT: (data['biasZMicroT'] as num).toDouble(),
      accuracy: data['accuracy'] as int,
      isUncalibrated: data['isUncalibrated'] as bool,
      batteryTempC: (data['batteryTempC'] as num).toDouble(),
      isCharging: data['isCharging'] as bool,
      isScreenOn: data['isScreenOn'] as bool,
    );
  }

  /// Konversi ke Map untuk serialisasi.
  Map<String, dynamic> toMap() {
    return {
      'timestampNs': timestampNs,
      'rawXMicroT': rawXMicroT,
      'rawYMicroT': rawYMicroT,
      'rawZMicroT': rawZMicroT,
      'biasXMicroT': biasXMicroT,
      'biasYMicroT': biasYMicroT,
      'biasZMicroT': biasZMicroT,
      'accuracy': accuracy,
      'isUncalibrated': isUncalibrated,
      'batteryTempC': batteryTempC,
      'isCharging': isCharging,
      'isScreenOn': isScreenOn,
    };
  }

  @override
  String toString() {
    return 'MagnetometerSample('
        'ts=${timestampNs}ns, '
        'raw=[$rawXMicroT, $rawYMicroT, $rawZMicroT]µT, '
        'total=${totalFieldMicroT.toStringAsFixed(2)}µT, '
        'uncal=$isUncalibrated)';
  }
}
