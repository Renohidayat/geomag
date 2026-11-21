/// Model data cuaca jam-jaman (hourly forecast) untuk grafik 24 jam.
class HourlyForecast {
  final DateTime time;
  final double tempC;
  final int weatherCode;
  final String weatherCondition;
  final String weatherEmoji;

  const HourlyForecast({
    required this.time,
    required this.tempC,
    required this.weatherCode,
    required this.weatherCondition,
    required this.weatherEmoji,
  });

  double get tempF => (tempC * 9 / 5) + 32.0;

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'tempC': tempC,
    'weatherCode': weatherCode,
    'weatherCondition': weatherCondition,
    'weatherEmoji': weatherEmoji,
  };

  factory HourlyForecast.fromJson(Map<String, dynamic> json) => HourlyForecast(
    time: DateTime.parse(json['time'] as String),
    tempC: (json['tempC'] as num).toDouble(),
    weatherCode: json['weatherCode'] as int? ?? 0,
    weatherCondition: json['weatherCondition'] as String? ?? 'Cerah',
    weatherEmoji: json['weatherEmoji'] as String? ?? '☀️',
  );
}

/// Model lokasi wilayah administratif Indonesia (Provinsi, Kota, Kecamatan, Desa/Dusun).
class AdmLocation {
  final String name;
  final String? district; // Kecamatan
  final String? regency; // Kabupaten / Kota
  final String province;
  final double latitude;
  final double longitude;
  final String? adm4Code; // Kode wilayah Kemendagri / BMKG
  final bool isGpsLocation;

  const AdmLocation({
    required this.name,
    this.district,
    this.regency,
    required this.province,
    required this.latitude,
    required this.longitude,
    this.adm4Code,
    this.isGpsLocation = false,
  });

  String get displayName {
    if (district != null && regency != null) {
      return '$name, $district, $regency';
    }
    if (regency != null) {
      return '$name, $regency';
    }
    return '$name, $province';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'district': district,
    'regency': regency,
    'province': province,
    'latitude': latitude,
    'longitude': longitude,
    'adm4Code': adm4Code,
    'isGpsLocation': isGpsLocation,
  };

  factory AdmLocation.fromJson(Map<String, dynamic> json) => AdmLocation(
    name: json['name'] as String,
    district: json['district'] as String?,
    regency: json['regency'] as String?,
    province: json['province'] as String? ?? 'Indonesia',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    adm4Code: json['adm4Code'] as String?,
    isGpsLocation: json['isGpsLocation'] as bool? ?? false,
  );
}
