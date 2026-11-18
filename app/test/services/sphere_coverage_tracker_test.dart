import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/sphere_coverage_tracker.dart';

void main() {
  group('SphereCoverageTracker', () {
    late SphereCoverageTracker tracker;

    setUp(() {
      tracker = SphereCoverageTracker();
    });

    test('Inisialisasi sektor awal berjumlah 18 dengan 0% cakupan', () {
      expect(tracker.totalSectorCount, equals(18));
      expect(tracker.coveredSectorCount, equals(0));
      expect(tracker.coveragePercentage, equals(0.0));
    });

    test('addSample mengenali kutub utara (+Z) dan kutub selatan (-Z)', () {
      // Sampel di kutub utara (+Z)
      for (var i = 0; i < 3; i++) {
        final sectorId = tracker.addSample(0.0, 0.0, 45.0);
        expect(sectorId, equals(0)); // id 0 adalah kutub atas
      }
      expect(tracker.coveredSectorCount, equals(1));

      // Sampel di kutub selatan (-Z)
      for (var i = 0; i < 3; i++) {
        final sectorId = tracker.addSample(0.0, 0.0, -45.0);
        expect(sectorId, equals(17)); // id 17 adalah kutub bawah
      }
      expect(tracker.coveredSectorCount, equals(2));
      expect(tracker.coveragePercentage, closeTo((2 / 18) * 100.0, 0.1));
    });

    test('addSample mengabaikan vektor magnitudo nol', () {
      final sectorId = tracker.addSample(0.0, 0.0, 0.0);
      expect(sectorId, isNull);
      expect(tracker.coveredSectorCount, equals(0));
    });

    test('Cakupan bola penuh saat seluruh 18 sektor diberi sampel cukup', () {
      // Sampel kutub atas (+Z)
      for (var i = 0; i < 3; i++) {
        tracker.addSample(0.0, 0.0, 45.0);
      }
      // Sampel kutub bawah (-Z)
      for (var i = 0; i < 3; i++) {
        tracker.addSample(0.0, 0.0, -45.0);
      }

      // Sampel cincin atas (8 arah azimuth, zenith = 60 derajat)
      final zenithTop = pi / 3.0; // 60 deg
      for (var i = 0; i < 8; i++) {
        final azimuth = (i + 0.5) * (pi / 4.0);
        final x = sin(zenithTop) * cos(azimuth) * 45.0;
        final y = sin(zenithTop) * sin(azimuth) * 45.0;
        final z = cos(zenithTop) * 45.0;
        for (var k = 0; k < 3; k++) {
          tracker.addSample(x, y, z);
        }
      }

      // Sampel cincin bawah (8 arah azimuth, zenith = 120 derajat)
      final zenithBottom = 2.0 * pi / 3.0; // 120 deg
      for (var i = 0; i < 8; i++) {
        final azimuth = (i + 0.5) * (pi / 4.0);
        final x = sin(zenithBottom) * cos(azimuth) * 45.0;
        final y = sin(zenithBottom) * sin(azimuth) * 45.0;
        final z = cos(zenithBottom) * 45.0;
        for (var k = 0; k < 3; k++) {
          tracker.addSample(x, y, z);
        }
      }

      expect(tracker.coveredSectorCount, equals(18));
      expect(tracker.coveragePercentage, equals(100.0));

      // Reset mengosongkan kembali
      tracker.reset();
      expect(tracker.coveredSectorCount, equals(0));
      expect(tracker.coveragePercentage, equals(0.0));
    });

    test('addSample dengan parameter pemusatan centerX, centerY, centerZ', () {
      // Offset hard-iron 100 uT di sumbu X, Y, Z
      const bx = 100.0;
      const by = 80.0;
      const bz = -50.0;

      // Titik di kutub utara (+Z) ditambah offset
      for (var i = 0; i < 3; i++) {
        final sectorId = tracker.addSample(
          bx,
          by,
          bz + 45.0,
          centerX: bx,
          centerY: by,
          centerZ: bz,
        );
        expect(sectorId, equals(0)); // id 0 adalah kutub atas
      }

      // Titik di kutub selatan (-Z) ditambah offset
      for (var i = 0; i < 3; i++) {
        final sectorId = tracker.addSample(
          bx,
          by,
          bz - 45.0,
          centerX: bx,
          centerY: by,
          centerZ: bz,
        );
        expect(sectorId, equals(17)); // id 17 adalah kutub bawah
      }

      expect(tracker.coveredSectorCount, equals(2));
    });
  });
}
