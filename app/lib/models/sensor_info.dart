/// Info sensor magnetometer dari perangkat Android.
class SensorInfo {
  /// Apakah sensor tersedia.
  final bool available;

  /// Apakah sensor yang dipakai adalah uncalibrated.
  final bool isUncalibrated;

  /// Nama sensor (dari Android).
  final String? name;

  /// Vendor sensor.
  final String? vendor;

  /// Versi sensor.
  final int? version;

  /// Resolusi sensor (mikroTesla).
  final double? resolutionMicroT;

  /// Rentang maksimum (mikroTesla).
  final double? maxRangeMicroT;

  /// Delay minimum antar event (mikrodetik).
  final int? minDelayUs;

  /// Delay maksimum antar event (mikrodetik).
  final int? maxDelayUs;

  /// Konsumsi daya (mA).
  final double? powerMa;

  const SensorInfo({
    required this.available,
    required this.isUncalibrated,
    this.name,
    this.vendor,
    this.version,
    this.resolutionMicroT,
    this.maxRangeMicroT,
    this.minDelayUs,
    this.maxDelayUs,
    this.powerMa,
  });

  /// Membuat instance dari Map yang dikirim MethodChannel Kotlin.
  factory SensorInfo.fromMap(Map<Object?, Object?> data) {
    return SensorInfo(
      available: data['available'] as bool? ?? false,
      isUncalibrated: data['isUncalibrated'] as bool? ?? false,
      name: data['name'] as String?,
      vendor: data['vendor'] as String?,
      version: data['version'] as int?,
      resolutionMicroT: (data['resolution'] as num?)?.toDouble(),
      maxRangeMicroT: (data['maxRange'] as num?)?.toDouble(),
      minDelayUs: data['minDelay'] as int?,
      maxDelayUs: data['maxDelay'] as int?,
      powerMa: (data['power'] as num?)?.toDouble(),
    );
  }

  /// Laju sampling maksimum dalam Hz (dari minDelay).
  double? get maxRateHz {
    if (minDelayUs == null || minDelayUs == 0) return null;
    return 1000000.0 / minDelayUs!;
  }

  @override
  String toString() {
    return 'SensorInfo(name=$name, vendor=$vendor, '
        'uncal=$isUncalibrated, res=$resolutionMicroT µT)';
  }
}
