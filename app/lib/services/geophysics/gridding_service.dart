import 'dart:math';

/// Titik data sebaran tak beraturan untuk interpolasi grid 2D.
class GridPoint {
  final double x;
  final double y;
  final double value;
  final String? stationId;

  const GridPoint({
    required this.x,
    required this.y,
    required this.value,
    this.stationId,
  });
}

/// Struktur data matriks grid 2D beraturan.
class Grid2D {
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final double dx;
  final double dy;
  final int nx;
  final int ny;
  final List<double> xCoords;
  final List<double> yCoords;
  final List<List<double>> values; // values[row_y][col_x]

  const Grid2D({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.dx,
    required this.dy,
    required this.nx,
    required this.ny,
    required this.xCoords,
    required this.yCoords,
    required this.values,
  });

  /// Mengambil nilai minimum dan maksimum dari seluruh sel grid.
  ({double min, double max}) get minMax {
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int r = 0; r < ny; r++) {
      for (int c = 0; c < nx; c++) {
        final v = values[r][c];
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
    }

    return (
      min: minVal.isFinite ? minVal : 0.0,
      max: maxVal.isFinite ? maxVal : 0.0,
    );
  }
}

/// Service fungsi murni untuk gridding 2D dari titik sebaran tak beraturan.
class GriddingService {
  const GriddingService();

  /// Melakukan interpolasi Inverse Distance Weighting (IDW) ke matriks Grid2D.
  Grid2D gridInverseDistanceWeighting({
    required List<GridPoint> points,
    int nx = 25,
    int ny = 25,
    double power = 2.0,
    double smoothing = 0.01,
    ({double xMin, double xMax, double yMin, double yMax})? bounds,
  }) {
    if (points.isEmpty) {
      throw ArgumentError('Daftar titik tidak boleh kosong untuk gridding');
    }

    double xMin, xMax, yMin, yMax;
    if (bounds != null) {
      xMin = bounds.xMin;
      xMax = bounds.xMax;
      yMin = bounds.yMin;
      yMax = bounds.yMax;
    } else {
      xMin = points.map((p) => p.x).reduce(min);
      xMax = points.map((p) => p.x).reduce(max);
      yMin = points.map((p) => p.y).reduce(min);
      yMax = points.map((p) => p.y).reduce(max);

      if (xMin == xMax) {
        xMin -= 1.0;
        xMax += 1.0;
      }
      if (yMin == yMax) {
        yMin -= 1.0;
        yMax += 1.0;
      }
    }

    final dx = (xMax - xMin) / max(1, nx - 1);
    final dy = (yMax - yMin) / max(1, ny - 1);

    final xCoords = List.generate(nx, (i) => xMin + i * dx);
    final yCoords = List.generate(ny, (j) => yMin + j * dy);

    final gridValues = List.generate(ny, (_) => List.filled(nx, 0.0));

    final nPts = points.length;
    final px = points.map((p) => p.x).toList();
    final py = points.map((p) => p.y).toList();
    final pv = points.map((p) => p.value).toList();

    for (int r = 0; r < ny; r++) {
      final gy = yCoords[r];
      for (int c = 0; c < nx; c++) {
        final gx = xCoords[c];

        int exactIdx = -1;
        double sumWeights = 0.0;
        double sumValWeight = 0.0;

        for (int i = 0; i < nPts; i++) {
          final distX = px[i] - gx;
          final distY = py[i] - gy;
          final distSq = distX * distX + distY * distY;

          if (distSq < 1e-12) {
            exactIdx = i;
            break;
          }

          final dist = sqrt(distSq);
          final w = 1.0 / pow(dist + smoothing, power);
          sumWeights += w;
          sumValWeight += w * pv[i];
        }

        if (exactIdx >= 0) {
          gridValues[r][c] = pv[exactIdx];
        } else {
          gridValues[r][c] =
              sumWeights > 0 ? sumValWeight / sumWeights : 0.0;
        }
      }
    }

    return Grid2D(
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
      values: gridValues,
    );
  }
}
