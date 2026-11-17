import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/analytic_signal_service.dart';
import 'package:geomag/services/gridding_service.dart';

void main() {
  const griddingService = GriddingService();
  const asService = AnalyticSignalService();

  group('GriddingService (IDW Interpolation)', () {
    test('exact node values match original scattered points', () {
      final pts = [
        const GridPoint(x: 0.0, y: 0.0, value: 100.0),
        const GridPoint(x: 10.0, y: 0.0, value: 200.0),
        const GridPoint(x: 0.0, y: 10.0, value: 300.0),
        const GridPoint(x: 10.0, y: 10.0, value: 400.0),
      ];

      final grid = griddingService.gridInverseDistanceWeighting(
        points: pts,
        nx: 3,
        ny: 3,
        power: 2.0,
      );

      expect(grid.nx, 3);
      expect(grid.ny, 3);
      expect(grid.dx, closeTo(5.0, 1e-4));
      expect(grid.dy, closeTo(5.0, 1e-4));

      // 4 sudut simpul grid harus cocok persis dengan titik input
      expect(grid.values[0][0], closeTo(100.0, 1e-4));
      expect(grid.values[0][2], closeTo(200.0, 1e-4));
      expect(grid.values[2][0], closeTo(300.0, 1e-4));
      expect(grid.values[2][2], closeTo(400.0, 1e-4));

      // Titik tengah (5, 5) harus sekitar 250.0
      expect(grid.values[1][1], closeTo(250.0, 1.0));

      final minMax = grid.minMax;
      expect(minMax.min, closeTo(100.0, 1e-4));
      expect(minMax.max, closeTo(400.0, 1e-4));
    });

    test('throws ArgumentError on empty points list', () {
      expect(
        () => griddingService.gridInverseDistanceWeighting(points: []),
        throwsArgumentError,
      );
    });
  });

  group('AnalyticSignalService 3D (Dart vs Python reference)', () {
    test('dipole anomaly has global peak |AS| at center and matches symmetry', () {
      const nx = 21;
      const ny = 21;
      const dx = 5.0;
      const dy = 5.0;
      const xMin = 0.0;
      const xMax = 100.0;
      const yMin = 0.0;
      const yMax = 100.0;

      final xCoords = List.generate(nx, (i) => xMin + i * dx);
      final yCoords = List.generate(ny, (j) => yMin + j * dy);

      const z0 = 15.0;
      final vals = List.generate(ny, (r) {
        final y = yCoords[r];
        return List.generate(nx, (c) {
          final x = xCoords[c];
          final distSq = (x - 50.0) * (x - 50.0) + (y - 50.0) * (y - 50.0) + z0 * z0;
          return 100000.0 * (2.0 * z0 * z0 - ((x - 50.0) * (x - 50.0) + (y - 50.0) * (y - 50.0))) /
              (distSq * distSq * sqrt(distSq));
        });
      });

      final inGrid = Grid2D(
        xMin: xMin,
        xMax: xMax,
        yMin: yMin,
        yMax: yMax,
        dx: dx,
        dy: dy,
        nx: nx,
        ny: ny,
        xCoords: xCoords,
        yCoords: yCoords,
        values: vals,
      );

      final res = asService.computeAnalyticSignal(inGrid);

      // 1. Nilai |AS| selalu non-negatif
      for (int r = 0; r < ny; r++) {
        for (int c = 0; c < nx; c++) {
          expect(res.asMagnitude.values[r][c], greaterThanOrEqualTo(0.0));
        }
      }

      // 2. Titik maksimum global |AS| harus berada tepat di simpul tengah (10, 10)
      double maxVal = -1.0;
      int maxR = -1;
      int maxC = -1;

      for (int r = 0; r < ny; r++) {
        for (int c = 0; c < nx; c++) {
          final v = res.asMagnitude.values[r][c];
          if (v > maxVal) {
            maxVal = v;
            maxR = r;
            maxC = c;
          }
        }
      }

      expect(maxR, 10);
      expect(maxC, 10);

      // 3. Simetri turunan horizontal Tx dan Ty berlawanan tanda di sekitar pusat
      final txLeft = res.tx.values[10][8];
      final txRight = res.tx.values[10][12];
      expect(txLeft, closeTo(-txRight, (txLeft.abs() * 0.1).clamp(0.01, double.infinity)));

      final tyTop = res.ty.values[8][10];
      final tyBottom = res.ty.values[12][10];
      expect(tyTop, closeTo(-tyBottom, (tyTop.abs() * 0.1).clamp(0.01, double.infinity)));
    });
  });
}
