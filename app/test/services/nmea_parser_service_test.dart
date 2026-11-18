import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/nmea_parser_service.dart';

void main() {
  const parser = NmeaParserService();

  group('NMEA Checksum Verification', () {
    test('computeChecksum menghasilkan 2 digit heksadesimal huruf besar', () {
      const payload = 'GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,';
      final csum = parser.computeChecksum(payload);
      expect(csum, '47');
    });

    test('verifySentence memvalidasi format dan menolak kalimat korup', () {
      const valid = '\$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47';
      final v1 = parser.verifySentence(valid);
      expect(v1.isValid, isTrue);
      expect(v1.payload, startsWith('GPGGA'));

      const corrupt = '\$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*99';
      final v2 = parser.verifySentence(corrupt);
      expect(v2.isValid, isFalse);

      const malformed = 'GPGGA,12345';
      final v3 = parser.verifySentence(malformed);
      expect(v3.isValid, isFalse);
    });
  });

  group('NMEA Coordinate Parsing', () {
    test('parseCoordinate mengonversi format ddmm.mmmm lintang selatan Indonesia', () {
      final lat = parser.parseCoordinate('0653.4800', 'S');
      expect(lat, isNotNull);
      expect(lat!, closeTo(-6.8913333, 1e-4));
    });

    test('parseCoordinate mengonversi format dddmm.mmmm bujur timur Indonesia', () {
      final lon = parser.parseCoordinate('10736.7200', 'E');
      expect(lon, isNotNull);
      expect(lon!, closeTo(107.6120000, 1e-4));
    });
  });

  group('NMEA Sentence Parsing (Dart vs Python benchmark)', () {
    test('parseSentence GGA RTK Fixed dari u-blox ZED-F9P', () {
      const payload = 'GNGGA,072412.00,0653.4800,S,10736.7200,E,4,18,0.65,765.20,M,25.4,M,1.2,0001';
      final csum = parser.computeChecksum(payload);
      final sentence = '\$$payload*$csum';

      final pos = parser.parseSentence(sentence);
      expect(pos, isNotNull);
      expect(pos!.sentenceType, 'GGA');
      expect(pos.latitude, closeTo(-6.8913, 1e-3));
      expect(pos.longitude, closeTo(107.6120, 1e-3));
      expect(pos.altitudeM, 765.20);
      expect(pos.hdop, 0.65);
      expect(pos.satellites, 18);
      expect(pos.fixQuality, GnssFixQuality.rtkFix);
      expect(pos.fixQuality.isHighPrecision, isTrue);
    });

    test('parseSentence RMC valid', () {
      const payload = 'GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W';
      final csum = parser.computeChecksum(payload);
      final sentence = '\$$payload*$csum';

      final pos = parser.parseSentence(sentence);
      expect(pos, isNotNull);
      expect(pos!.sentenceType, 'RMC');
      expect(pos.latitude, closeTo(48.1173, 1e-3));
      expect(pos.longitude, closeTo(11.5167, 1e-3));
      expect(pos.fixQuality, GnssFixQuality.gpsFix);
    });

    test('parseSentence menolak RMC invalid status V', () {
      const payload = 'GPRMC,123519,V,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W';
      final csum = parser.computeChecksum(payload);
      final sentence = '\$$payload*$csum';

      final pos = parser.parseSentence(sentence);
      expect(pos, isNull);
    });
  });
}
