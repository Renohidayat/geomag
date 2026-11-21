import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/adm4_service.dart';

void main() {
  group('Adm4Service Unit Tests', () {
    late Adm4Service service;

    setUp(() {
      service = Adm4Service();
    });

    test('defaultLocations memuat Cimalaka dan wilayah Sumedang', () {
      final locs = Adm4Service.defaultLocations;
      expect(locs.isNotEmpty, isTrue);

      final cimalaka = locs.firstWhere((l) => l.name == 'Cimalaka');
      expect(cimalaka.district, 'Kec. Cimalaka');
      expect(cimalaka.regency, 'Kab. Sumedang');
      expect(cimalaka.province, 'Jawa Barat');
      expect(cimalaka.latitude, closeTo(-6.81, 0.05));
      expect(cimalaka.longitude, closeTo(107.94, 0.05));
    });

    test('searchLocal mengembalikan hasil berdasarkan nama desa atau kecamatan', () {
      final results = service.searchLocal('cimalaka');
      expect(results.length, greaterThanOrEqualTo(1));
      expect(results.first.name, 'Cimalaka');

      final sumedangResults = service.searchLocal('Sumedang');
      expect(sumedangResults.length, greaterThanOrEqualTo(3));
      for (final r in sumedangResults) {
        expect(
          r.displayName.toLowerCase().contains('sumedang') ||
              r.regency?.toLowerCase().contains('sumedang') == true,
          isTrue,
        );
      }
    });

    test('searchLocal case-insensitive dan query kosong mengembalikan semua default', () {
      expect(service.searchLocal('   ').length, Adm4Service.defaultLocations.length);
      expect(service.searchLocal('BANDUNG').isNotEmpty, isTrue);
      expect(service.searchLocal('bandung').length, service.searchLocal('BANDUNG').length);
    });

    test('displayName memformat string secara terstruktur', () {
      final cimalaka = Adm4Service.defaultLocations.firstWhere((l) => l.name == 'Cimalaka');
      expect(cimalaka.displayName, contains('Cimalaka'));
      expect(cimalaka.displayName, contains('Sumedang'));
    });
  });
}
