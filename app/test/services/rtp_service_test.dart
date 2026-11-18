import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/gridding_service.dart';
import 'package:geomag/services/rtp_service.dart';

Grid2D createSyntheticEquatorialDipole({
  int nx = 17,
  int ny = 17,
  double dx = 5.0,
  double dy = 5.0,
  double incDeg = -15.0,
  double decDeg = 1.0,
}) {
  final xCoords = List.generate(nx, (i) => i * dx);
  final yCoords = List.generate(ny, (j) => j * dy);

  const x0 = 40.0;
  const y0 = 40.0;
  const z0 = 10.0;

  final inc = incDeg * pi / 180.0;
  final dec = decDeg * pi / 180.0;
  final l = cos(inc) * sin(dec);
  final m = cos(inc) * cos(dec);
  final n = sin(inc);

  const mMag = 100000.0;
  final values = List.generate(ny, (j) {
    final y = yCoords[j];
    final ry = y - y0;
    return List.generate(nx, (i) {
      final x = xCoords[i];
      final rx = x - x0;
      const rz = z0;

      final rSq = rx * rx + ry * ry + rz * rz;
      final r5 = pow(rSq, 2.5).toDouble();

      final rDotM = l * rx + m * ry + n * rz;

      final bx = mMag * (3.0 * rx * rDotM - l * rSq) / r5;
      final by = mMag * (3.0 * ry * rDotM - m * rSq) / r5;
      final bz = mMag * (3.0 * rz * rDotM - n * rSq) / r5;

      return l * bx + m * by + n * bz;
    });
  });

  return Grid2D(
    xMin: 0.0,
    xMax: (nx - 1) * dx,
    yMin: 0.0,
    yMax: (ny - 1) * dy,
    dx: dx,
    dy: dy,
    nx: nx,
    ny: ny,
    xCoords: xCoords,
    yCoords: yCoords,
    values: values,
  );
}

void main() {
  const rtpService = RtpService();

  group('Stabilized RTP (Reduction to Pole) - Dart vs Python', () {
    test('computeStabilizedRtp menggeser puncak anomali dipol miring ke pusat sumber', () {
      final grid = createSyntheticEquatorialDipole(incDeg: -15.0);

      final rtpGrid = rtpService.computeStabilizedRtp(
        grid,
        inclinationDeg: -15.0,
        declinationDeg: 1.0,
        pseudoInclinationDeg: 20.0,
      );

      expect(rtpGrid.nx, grid.nx);
      expect(rtpGrid.ny, grid.ny);

      // Cari koordinat puncak anomali setelah RTP
      double maxVal = double.negativeInfinity;
      int peakR = 0;
      int peakC = 0;

      for (int r = 0; r < rtpGrid.ny; r++) {
        for (int c = 0; c < rtpGrid.nx; c++) {
          final v = rtpGrid.values[r][c];
          expect(v.isNaN, isFalse);
          expect(v.isInfinite, isFalse);
          if (v > maxVal) {
            maxVal = v;
            peakR = r;
            peakC = c;
          }
        }
      }

      final peakX = rtpGrid.xCoords[peakC];
      final peakY = rtpGrid.yCoords[peakR];

      // Jarak puncak ke pusat sumber (40m, 40m) harus dalam radius 1 grid cell (<= 5m)
      final distToCenter = sqrt(pow(peakX - 40.0, 2) + pow(peakY - 40.0, 2));
      expect(distToCenter, lessThanOrEqualTo(5.0));
    });

    test('computeStabilizedRtp stabil pada inklinasi ekuator mendekati nol (I = -2°)', () {
      final grid = createSyntheticEquatorialDipole(incDeg: -2.0);

      final rtpGrid = rtpService.computeStabilizedRtp(
        grid,
        inclinationDeg: -2.0,
        declinationDeg: 0.5,
        pseudoInclinationDeg: 20.0,
      );

      double rawMax = 0.0;
      for (final row in grid.values) {
        for (final v in row) {
          rawMax = max(rawMax, v.abs());
        }
      }

      double rtpMax = 0.0;
      for (final row in rtpGrid.values) {
        for (final v in row) {
          expect(v.isNaN, isFalse);
          expect(v.isInfinite, isFalse);
          rtpMax = max(rtpMax, v.abs());
        }
      }

      // Rasio amplifikasi harus terkendali, tidak meledak akibat pembagian nol
      expect(rtpMax, lessThan(rawMax * 10.0));
    });
  });
}
