// Kualitas penentuan posisi (Fix Quality) sesuai standar NMEA-0183 (GGA field 6).
enum GnssFixQuality {
  /// 0: Tidak ada fix / sinyal tidak valid.
  invalid,

  /// 1: GPS Standalone (SPS) standar (~2-5 meter).
  gpsFix,

  /// 2: Differential GPS (DGPS) (~0.5-1.5 meter).
  dgpsFix,

  /// 3: PPS Fix.
  ppsFix,

  /// 4: RTK Fixed berakurasi centimeter (< 2 cm).
  rtkFix,

  /// 5: RTK Float berakurasi sub-meter (~20-50 cm).
  rtkFloat,

  /// 6: Dead reckoning / estimasi sensor gerak.
  estimated,
}

extension GnssFixQualityExtension on GnssFixQuality {
  String get label {
    switch (this) {
      case GnssFixQuality.invalid:
        return 'Tidak Ada Fix';
      case GnssFixQuality.gpsFix:
        return 'GPS Standar (SPS)';
      case GnssFixQuality.dgpsFix:
        return 'DGPS (Sub-meter)';
      case GnssFixQuality.ppsFix:
        return 'PPS Fix';
      case GnssFixQuality.rtkFix:
        return 'RTK Fix (Centimeter)';
      case GnssFixQuality.rtkFloat:
        return 'RTK Float (Sub-meter)';
      case GnssFixQuality.estimated:
        return 'Estimasi (Dead Reckoning)';
    }
  }

  /// Menunjukkan apakah fix memiliki akurasi survei tinggi (DGPS / RTK).
  bool get isHighPrecision =>
      this == GnssFixQuality.rtkFix ||
      this == GnssFixQuality.rtkFloat ||
      this == GnssFixQuality.dgpsFix;
}

/// Data koordinat dan status penerimaan satelit hasil parsing kalimat NMEA.
class NmeaPosition {
  final double latitude;
  final double longitude;
  final double? altitudeM;
  final double? hdop;
  final int? satellites;
  final GnssFixQuality fixQuality;
  final String sentenceType;
  final String rawSentence;
  final DateTime timestamp;

  const NmeaPosition({
    required this.latitude,
    required this.longitude,
    this.altitudeM,
    this.hdop,
    this.satellites,
    required this.fixQuality,
    required this.sentenceType,
    required this.rawSentence,
    required this.timestamp,
  });

  @override
  String toString() =>
      'NmeaPosition(lat: ${latitude.toStringAsFixed(6)}, lon: ${longitude.toStringAsFixed(6)}, '
      'alt: ${altitudeM?.toStringAsFixed(1)}m, hdop: $hdop, fix: ${fixQuality.name})';
}

/// Layanan untuk memvalidasi dan mem-parsing stream kalimat NMEA-0183 GNSS.
class NmeaParserService {
  const NmeaParserService();

  /// Menghitung nilai checksum XOR 2 digit hexadesimal dari string payload (tanpa '$' dan '*').
  String computeChecksum(String payload) {
    int csum = 0;
    for (int i = 0; i < payload.length; i++) {
      csum ^= payload.codeUnitAt(i);
    }
    return csum.toRadixString(16).padLeft(2, '0').toUpperCase();
  }

  /// Memverifikasi struktur kalimat NMEA dan kecocokan checksum XOR.
  ({bool isValid, String payload}) verifySentence(String sentence) {
    final trimmed = sentence.trim();
    if (!trimmed.startsWith('\$') || !trimmed.contains('*')) {
      return (isValid: false, payload: '');
    }

    final starIdx = trimmed.indexOf('*');
    final payload = trimmed.substring(1, starIdx);
    final expectedChecksum = trimmed.substring(starIdx + 1).trim().toUpperCase();

    final actualChecksum = computeChecksum(payload);
    if (actualChecksum != expectedChecksum) {
      return (isValid: false, payload: '');
    }

    return (isValid: true, payload: payload);
  }

  /// Mengonversi format koordinat NMEA (`ddmm.mmmm` atau `dddmm.mmmm`) menjadi derajat desimal.
  ///
  /// Contoh: `0653.4800, S` -> `-6.8913333...`
  /// Contoh: `10736.7200, E` -> `107.6120000...`
  double? parseCoordinate(String coordStr, String direction) {
    if (coordStr.isEmpty || direction.isEmpty) return null;

    final val = double.tryParse(coordStr);
    if (val == null) return null;

    final degrees = (val / 100.0).floor();
    final minutes = val - (degrees * 100.0);
    double decimal = degrees + (minutes / 60.0);

    final dir = direction.trim().toUpperCase();
    if (dir == 'S' || dir == 'W') {
      decimal = -decimal;
    }

    return double.parse(decimal.toStringAsFixed(7));
  }

  /// Mem-parsing kalimat NMEA sembarang (`$GPGGA`, `$GNGGA`, `$GPRMC`, `$GNRMC`, dsb).
  NmeaPosition? parseSentence(String sentence, {DateTime? timestamp}) {
    final verified = verifySentence(sentence);
    if (!verified.isValid) return null;

    final payload = verified.payload;
    final commaIdx = payload.indexOf(',');
    if (commaIdx == -1) return null;

    final typeCode = payload.substring(0, commaIdx).toUpperCase();
    final ts = timestamp ?? DateTime.now();

    if (typeCode.endsWith('GGA')) {
      return _parseGga(payload, sentence.trim(), ts);
    } else if (typeCode.endsWith('RMC')) {
      return _parseRmc(payload, sentence.trim(), ts);
    }

    return null;
  }

  NmeaPosition? _parseGga(String payload, String raw, DateTime ts) {
    final fields = payload.split(',');
    if (fields.length < 10) return null;

    final lat = parseCoordinate(fields[2], fields[3]);
    final lon = parseCoordinate(fields[4], fields[5]);
    if (lat == null || lon == null) return null;

    final fixCode = fields[6].trim();
    final GnssFixQuality quality;
    switch (fixCode) {
      case '1':
        quality = GnssFixQuality.gpsFix;
        break;
      case '2':
        quality = GnssFixQuality.dgpsFix;
        break;
      case '3':
        quality = GnssFixQuality.ppsFix;
        break;
      case '4':
        quality = GnssFixQuality.rtkFix;
        break;
      case '5':
        quality = GnssFixQuality.rtkFloat;
        break;
      case '6':
        quality = GnssFixQuality.estimated;
        break;
      default:
        quality = GnssFixQuality.invalid;
    }

    final satellites = int.tryParse(fields[7]);
    final hdop = double.tryParse(fields[8]);
    final altitude = double.tryParse(fields[9]);

    return NmeaPosition(
      latitude: lat,
      longitude: lon,
      altitudeM: altitude,
      hdop: hdop,
      satellites: satellites,
      fixQuality: quality,
      sentenceType: 'GGA',
      rawSentence: raw,
      timestamp: ts,
    );
  }

  NmeaPosition? _parseRmc(String payload, String raw, DateTime ts) {
    final fields = payload.split(',');
    if (fields.length < 7) return null;

    // Status: 'A' = Valid, 'V' = Warning
    final status = fields[2].trim().toUpperCase();
    if (status != 'A') return null;

    final lat = parseCoordinate(fields[3], fields[4]);
    final lon = parseCoordinate(fields[5], fields[6]);
    if (lat == null || lon == null) return null;

    return NmeaPosition(
      latitude: lat,
      longitude: lon,
      altitudeM: null,
      hdop: null,
      satellites: null,
      fixQuality: GnssFixQuality.gpsFix,
      sentenceType: 'RMC',
      rawSentence: raw,
      timestamp: ts,
    );
  }
}
