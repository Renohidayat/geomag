import 'dart:math';

import 'package:geomag/services/geophysics/gridding_service.dart';

/// Hasil perhitungan sinyal analitik 3D geomagnetik dan turunan spasialnya.
class AnalyticSignalResult {
  /// Turunan horizontal sumbu X (dT/dx) dalam nT/m.
  final Grid2D tx;

  /// Turunan horizontal sumbu Y (dT/dy) dalam nT/m.
  final Grid2D ty;

  /// Turunan vertikal sumbu Z (dT/dz) dalam nT/m (dari transformasi Fourier 2D).
  final Grid2D tz;

  /// Magnitudo Analytic Signal 3D (|AS| = sqrt(Tx^2 + Ty^2 + Tz^2)) dalam nT/m.
  final Grid2D asMagnitude;

  const AnalyticSignalResult({
    required this.tx,
    required this.ty,
    required this.tz,
    required this.asMagnitude,
  });
}

/// Service fungsi murni untuk menghitung Analytic Signal 3D geomagnetik.
///
/// Menggunakan formulasi Roest et al. (1992) & MacLeod et al. (1993):
///   |AS(x, y)| = sqrt((dT/dx)^2 + (dT/dy)^2 + (dT/dz)^2)
class AnalyticSignalService {
  const AnalyticSignalService();

  /// Menghitung Analytic Signal 3D dari sebuah [Grid2D].
  AnalyticSignalResult computeAnalyticSignal(Grid2D grid) {
    final vals = grid.values;
    final ny = grid.ny;
    final nx = grid.nx;
    final dx = grid.dx;
    final dy = grid.dy;

    // 1. Turunan Horizontal Tx (dT/dx)
    final tx = List.generate(ny, (_) => List.filled(nx, 0.0));
    if (nx > 1) {
      for (int r = 0; r < ny; r++) {
        tx[r][0] = (vals[r][1] - vals[r][0]) / dx;
        for (int c = 1; c < nx - 1; c++) {
          tx[r][c] = (vals[r][c + 1] - vals[r][c - 1]) / (2.0 * dx);
        }
        tx[r][nx - 1] = (vals[r][nx - 1] - vals[r][nx - 2]) / dx;
      }
    }

    // 2. Turunan Horizontal Ty (dT/dy)
    final ty = List.generate(ny, (_) => List.filled(nx, 0.0));
    if (ny > 1) {
      for (int c = 0; c < nx; c++) {
        ty[0][c] = (vals[1][c] - vals[0][c]) / dy;
        for (int r = 1; r < ny - 1; r++) {
          ty[r][c] = (vals[r + 1][c] - vals[r - 1][c]) / (2.0 * dy);
        }
        ty[ny - 1][c] = (vals[ny - 1][c] - vals[ny - 2][c]) / dy;
      }
    }

    // 3. Turunan Vertikal Tz via 2D FFT
    final py = _nextPow2(max(ny, 16));
    final px = _nextPow2(max(nx, 16));

    // Hitung rata-rata nilai grid untuk detrending
    double sum = 0.0;
    for (int r = 0; r < ny; r++) {
      for (int c = 0; c < nx; c++) {
        sum += vals[r][c];
      }
    }
    final meanVal = sum / (ny * nx);

    // Padding matriks dengan edge continuation
    final padReal = List.generate(py, (_) => List.filled(px, 0.0));
    final padImag = List.generate(py, (_) => List.filled(px, 0.0));

    for (int r = 0; r < py; r++) {
      final clampedR = r.clamp(0, ny - 1);
      for (int c = 0; c < px; c++) {
        final clampedC = c.clamp(0, nx - 1);
        padReal[r][c] = vals[clampedR][clampedC] - meanVal;
      }
    }

    // Forward 2D FFT
    _fft2d(padReal, padImag, false);

    // Filter wavenumber domain |k| = sqrt(kx^2 + ky^2)
    final kx = _fftfreq(px, dx);
    final ky = _fftfreq(py, dy);

    for (int r = 0; r < py; r++) {
      final kY = 2.0 * pi * ky[r];
      for (int c = 0; c < px; c++) {
        final kX = 2.0 * pi * kx[c];
        final kMag = sqrt(kX * kX + kY * kY);

        padReal[r][c] *= kMag;
        padImag[r][c] *= kMag;
      }
    }

    // Inverse 2D FFT
    _fft2d(padReal, padImag, true);

    // Ekstrak unpadded Tz dan hitung Analytic Signal
    final tz = List.generate(ny, (_) => List.filled(nx, 0.0));
    final asMag = List.generate(ny, (_) => List.filled(nx, 0.0));

    for (int r = 0; r < ny; r++) {
      for (int c = 0; c < nx; c++) {
        final zVal = padReal[r][c];
        tz[r][c] = zVal;

        final xVal = tx[r][c];
        final yVal = ty[r][c];
        asMag[r][c] = sqrt(xVal * xVal + yVal * yVal + zVal * zVal);
      }
    }

    Grid2D makeGrid(List<List<double>> arr) {
      return Grid2D(
        xMin: grid.xMin,
        xMax: grid.xMax,
        yMin: grid.yMin,
        yMax: grid.yMax,
        dx: grid.dx,
        dy: grid.dy,
        nx: grid.nx,
        ny: grid.ny,
        xCoords: grid.xCoords,
        yCoords: grid.yCoords,
        values: arr,
      );
    }

    return AnalyticSignalResult(
      tx: makeGrid(tx),
      ty: makeGrid(ty),
      tz: makeGrid(tz),
      asMagnitude: makeGrid(asMag),
    );
  }

  static int _nextPow2(int n) {
    if (n <= 1) return 1;
    int p = 1;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }

  static List<double> _fftfreq(int n, double d) {
    final val = 1.0 / (n * d);
    final results = List.filled(n, 0.0);
    final half = (n - 1) ~/ 2 + 1;

    for (int i = 0; i < half; i++) {
      results[i] = i * val;
    }
    for (int i = half; i < n; i++) {
      results[i] = (i - n) * val;
    }
    return results;
  }

  static void _fft2d(
    List<List<double>> real,
    List<List<double>> imag,
    bool invert,
  ) {
    final nrows = real.length;
    final ncols = real[0].length;

    // 1D FFT pada setiap baris
    for (int r = 0; r < nrows; r++) {
      _fft1d(real[r], imag[r], invert);
    }

    // 1D FFT pada setiap kolom
    final colReal = List.filled(nrows, 0.0);
    final colImag = List.filled(nrows, 0.0);

    for (int c = 0; c < ncols; c++) {
      for (int r = 0; r < nrows; r++) {
        colReal[r] = real[r][c];
        colImag[r] = imag[r][c];
      }

      _fft1d(colReal, colImag, invert);

      for (int r = 0; r < nrows; r++) {
        real[r][c] = colReal[r];
        imag[r][c] = colImag[r];
      }
    }
  }

  static void _fft1d(List<double> real, List<double> imag, bool invert) {
    final n = real.length;

    // Bit-reversal permutation
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        final tr = real[i];
        real[i] = real[j];
        real[j] = tr;
        final ti = imag[i];
        imag[i] = imag[j];
        imag[j] = ti;
      }
      int k = n >> 1;
      while (k <= j) {
        j -= k;
        k >>= 1;
      }
      j += k;
    }

    // Cooley-Tukey butterfly
    for (int len = 2; len <= n; len <<= 1) {
      final double ang = 2 * pi / len * (invert ? -1 : 1);
      final double wlenR = cos(ang);
      final double wlenI = sin(ang);

      for (int i = 0; i < n; i += len) {
        double wR = 1.0;
        double wI = 0.0;
        final halfLen = len ~/ 2;

        for (int step = 0; step < halfLen; step++) {
          final uR = real[i + step];
          final uI = imag[i + step];
          final vrPos = i + step + halfLen;

          final vR = real[vrPos] * wR - imag[vrPos] * wI;
          final vI = real[vrPos] * wI + imag[vrPos] * wR;

          real[i + step] = uR + vR;
          imag[i + step] = uI + vI;
          real[vrPos] = uR - vR;
          imag[vrPos] = uI - vI;

          final nextWR = wR * wlenR - wI * wlenI;
          final nextWI = wR * wlenI + wI * wlenR;
          wR = nextWR;
          wI = nextWI;
        }
      }
    }

    if (invert) {
      for (int i = 0; i < n; i++) {
        real[i] /= n;
        imag[i] /= n;
      }
    }
  }
}
