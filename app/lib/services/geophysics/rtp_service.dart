import 'dart:math';

import 'package:geomag/services/geophysics/gridding_service.dart';

/// Layanan untuk menghitung Reduction to Pole (RTP) stabil pada lintang magnetik rendah.
///
/// Pada wilayah ekuator dan lintang rendah (seperti Indonesia dengan inklinasi |I| < 20°),
/// filter RTP standar meledak karena pembagian dengan sin(I) mendekati 0.
/// Layanan ini menerapkan regularisasi pseudo-inclination (Li & Oldenburg, 2001; MacLeod et al., 1993)
/// yang mempertahankan pergeseran fase ke kutub magnetik sekaligus membatasi magnitudo filter
/// agar terbebas dari derau garis-garis utara-selatan (striations).
class RtpService {
  const RtpService();

  /// Menghitung Reduction to Pole (RTP) teratur dari sebuah [Grid2D].
  ///
  /// Parameter:
  /// - [grid]: Grid anomali medan total (ΔT)
  /// - [inclinationDeg]: Sudut inklinasi medan bumi (derajat)
  /// - [declinationDeg]: Sudut deklinasi medan bumi (derajat dari Utara ke Timur)
  /// - [pseudoInclinationDeg]: Ambang batas minimum regularisasi (default 20.0°)
  Grid2D computeStabilizedRtp(
    Grid2D grid, {
    required double inclinationDeg,
    required double declinationDeg,
    double pseudoInclinationDeg = 20.0,
  }) {
    final vals = grid.values;
    final ny = grid.ny;
    final nx = grid.nx;
    final dx = grid.dx;
    final dy = grid.dy;

    final inc = inclinationDeg * pi / 180.0;
    final dec = declinationDeg * pi / 180.0;
    final incP = max(5.0, pseudoInclinationDeg) * pi / 180.0;

    // Vektor arah medan bumi (X=East, Y=North, Z=Down)
    final l = cos(inc) * sin(dec);
    final m = cos(inc) * cos(dec);
    final n = sin(inc);

    final py = _nextPow2(max(ny, 16));
    final px = _nextPow2(max(nx, 16));

    // 1. Detrending nilai rata-rata grid
    double sum = 0.0;
    for (int r = 0; r < ny; r++) {
      for (int c = 0; c < nx; c++) {
        sum += vals[r][c];
      }
    }
    final meanVal = sum / (ny * nx);

    // 2. Padding matriks ke pangkat 2
    final padReal = List.generate(py, (_) => List.filled(px, 0.0));
    final padImag = List.generate(py, (_) => List.filled(px, 0.0));

    for (int r = 0; r < py; r++) {
      final clampedR = r.clamp(0, ny - 1);
      for (int c = 0; c < px; c++) {
        final clampedC = c.clamp(0, nx - 1);
        padReal[r][c] = vals[clampedR][clampedC] - meanVal;
      }
    }

    // 3. Transformasi Fourier Maju 2D
    _fft2d(padReal, padImag, false);

    // 4. Filter RTP teratur di domain bilangan gelombang
    final kx = _fftfreq(px, dx);
    final ky = _fftfreq(py, dy);
    final delta = sin(incP) * sin(incP); // ambang magnitudo minimum

    for (int r = 0; r < py; r++) {
      final kY = 2.0 * pi * ky[r];
      for (int c = 0; c < px; c++) {
        final kX = 2.0 * pi * kx[c];
        final kMag = sqrt(kX * kX + kY * kY);

        if (kMag == 0.0) {
          // Komponen DC tidak diubah
          continue;
        }

        // Respon arah kompleks Θ(k) = (n*|k| + i*(l*kx + m*ky)) / |k|
        final thetaR = n;
        final thetaI = (l * kX + m * kY) / kMag;

        // H(k) = Θ(k)^2 = (thetaR^2 - thetaI^2) + i * (2 * thetaR * thetaI)
        final hR = thetaR * thetaR - thetaI * thetaI;
        final hI = 2.0 * thetaR * thetaI;
        final hMag = sqrt(hR * hR + hI * hI);

        // Regularisasi phase-preserving
        final double hRegMag = max(hMag, delta);
        final double hRegR;
        final double hRegI;

        if (hMag == 0.0) {
          hRegR = delta;
          hRegI = 0.0;
        } else {
          final scale = hRegMag / hMag;
          hRegR = hR * scale;
          hRegI = hI * scale;
        }

        // Filter RTP terbalik: 1 / H_reg = H_reg* / |H_reg|^2
        final denom = hRegR * hRegR + hRegI * hRegI;
        final fRtpR = hRegR / denom;
        final fRtpI = -hRegI / denom;

        // Kalikan spektrum Fourier data dengan filter RTP
        final curR = padReal[r][c];
        final curI = padImag[r][c];

        padReal[r][c] = curR * fRtpR - curI * fRtpI;
        padImag[r][c] = curR * fRtpI + curI * fRtpR;
      }
    }

    // 5. Transformasi Fourier Balik 2D
    _fft2d(padReal, padImag, true);

    // 6. Unpad dan tambahkan kembali nilai mean
    final rtpVals = List.generate(ny, (_) => List.filled(nx, 0.0));
    for (int r = 0; r < ny; r++) {
      for (int c = 0; c < nx; c++) {
        rtpVals[r][c] = padReal[r][c] + meanVal;
      }
    }

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
      values: rtpVals,
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

    // 1D FFT baris
    for (int r = 0; r < nrows; r++) {
      _fft1d(real[r], imag[r], invert);
    }

    // 1D FFT kolom
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

    for (int len = 2; len <= n; len <<= 1) {
      final double ang = 2 * pi / len * (invert ? -1 : 1);
      final double wlenR = cos(ang);
      final double wlenI = sin(ang);

      for (int i = 0; i < n; i += len) {
        double wR = 1.0;
        double wI = 0.0;
        final half = len >> 1;

        for (int k = 0; k < half; k++) {
          final uR = real[i + k];
          final uI = imag[i + k];
          final vR = real[i + k + half] * wR - imag[i + k + half] * wI;
          final vI = real[i + k + half] * wI + imag[i + k + half] * wR;

          real[i + k] = uR + vR;
          imag[i + k] = uI + vI;
          real[i + k + half] = uR - vR;
          imag[i + k + half] = uI - vI;

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
