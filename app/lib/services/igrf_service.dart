import 'dart:math';

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'igrf_coefficients.dart';

/// Hasil perhitungan model medan utama bumi IGRF-14.
class IgrfResult {
  /// Komponen horizontal utara (North, X) dalam nT.
  final double xNorthNt;

  /// Komponen horizontal timur (East, Y) dalam nT.
  final double yEastNt;

  /// Komponen vertikal ke bawah (Down, Z) dalam nT.
  final double zDownNt;

  /// Intensitas medan horizontal (H = sqrt(X^2 + Y^2)) dalam nT.
  final double hHorizontalNt;

  /// Intensitas medan total (F = sqrt(H^2 + Z^2)) dalam nT.
  final double fTotalNt;

  /// Sudut deklinasi magnetik (D) dalam derajat (-180° s/d +180°).
  final double declinationDeg;

  /// Sudut inklinasi/dip magnetik (I) dalam derajat (-90° s/d +90°).
  final double inclinationDeg;

  const IgrfResult({
    required this.xNorthNt,
    required this.yEastNt,
    required this.zDownNt,
    required this.hHorizontalNt,
    required this.fTotalNt,
    required this.declinationDeg,
    required this.inclinationDeg,
  });

  @override
  String toString() {
    return 'IgrfResult(F: ${fTotalNt.toStringAsFixed(1)} nT, '
        'H: ${hHorizontalNt.toStringAsFixed(1)} nT, '
        'X: ${xNorthNt.toStringAsFixed(1)} nT, '
        'Y: ${yEastNt.toStringAsFixed(1)} nT, '
        'Z: ${zDownNt.toStringAsFixed(1)} nT, '
        'D: ${declinationDeg.toStringAsFixed(2)}°, '
        'I: ${inclinationDeg.toStringAsFixed(2)}°)';
  }
}

/// Service untuk evaluasi model IGRF-14 dan kalkulasi anomali geomagnetik ΔT.
class IgrfService {
  // Konstanta Geodetik WGS-84
  static const double wgs84AKm = 6378.137;
  static const double wgs84F = 1.0 / 298.257223563;
  static final double wgs84BKm = wgs84AKm * (1.0 - wgs84F);

  // Radius acuan bola geomagnetik standar (km)
  static const double earthRadiusKm = 6371.2;

  const IgrfService();

  /// Mengonversi objek [DateTime] menjadi tahun desimal pecahan (misal 2025.5).
  static double toDecimalYear(DateTime dt) {
    final year = dt.year;
    final startOfYear = DateTime.utc(year, 1, 1);
    final startOfNextYear = DateTime.utc(year + 1, 1, 1);

    final totalMs = startOfNextYear.difference(startOfYear).inMilliseconds;
    final elapsedMs = dt.difference(startOfYear).inMilliseconds;

    return year + (elapsedMs / totalMs);
  }

  /// Menghitung komponen medan IGRF-14 dari koordinat geodetik dan waktu [DateTime].
  IgrfResult calculate({
    required double latitudeDeg,
    required double longitudeDeg,
    double altitudeKm = 0.0,
    required DateTime date,
    int maxDegree = 13,
  }) {
    return calculateForDecimalYear(
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      altitudeKm: altitudeKm,
      decimalYear: toDecimalYear(date),
      maxDegree: maxDegree,
    );
  }

  /// Menghitung komponen medan IGRF-14 dari koordinat geodetik dan tahun desimal pecahan.
  IgrfResult calculateForDecimalYear({
    required double latitudeDeg,
    required double longitudeDeg,
    double altitudeKm = 0.0,
    required double decimalYear,
    int maxDegree = 13,
  }) {
    final clampedDegree = maxDegree.clamp(1, 13);

    // 1. Interpolasi koefisien Gauss g(n,m) dan h(n,m)
    final gMap = <int, double>{};
    final hMap = <int, double>{};

    final epochs = igrf14Epochs;
    final nEpochs = epochs.length;
    final firstEpoch = epochs.first;
    final lastEpoch = epochs.last;

    for (final record in igrf14Coeffs) {
      final key = (record.n << 4) | record.m;
      final vals = record.values;
      double val;

      if (decimalYear <= firstEpoch) {
        val = vals[0];
      } else if (decimalYear >= lastEpoch) {
        // Proyeksi secular variation (kolom terakhir)
        final sv = vals.last;
        final dt = decimalYear - lastEpoch;
        val = vals[vals.length - 2] + dt * sv;
      } else {
        // Interpolasi linear antar epoch 5 tahunan
        int idx = 0;
        while (idx < nEpochs - 1 && epochs[idx + 1] <= decimalYear) {
          idx++;
        }
        final t1 = epochs[idx];
        final t2 = epochs[idx + 1];
        final v1 = vals[idx];
        final v2 = vals[idx + 1];
        final alpha = (decimalYear - t1) / (t2 - t1);
        val = v1 + alpha * (v2 - v1);
      }

      if (record.isH) {
        hMap[key] = val;
      } else {
        gMap[key] = val;
      }
    }

    // 2. Konversi Geodetik ke Geosentrik
    final latRad = latitudeDeg * (pi / 180.0);
    final lonRad = longitudeDeg * (pi / 180.0);

    final cosLat = cos(latRad);
    final sinLat = sin(latRad);
    final cos2Lat = cosLat * cosLat;
    final sin2Lat = sinLat * sinLat;

    final a = wgs84AKm;
    final b = wgs84BKm;
    final tmp = altitudeKm * sqrt(a * a * cos2Lat + b * b * sin2Lat);
    final beta = atan2(
      (tmp + b * b) * sinLat,
      (tmp + a * a) * cosLat,
    );
    final colatRad = (pi / 2.0) - beta;

    final ba2 = (b / a) * (b / a);
    final ba4 = ba2 * ba2;
    final rKm = sqrt(
      altitudeKm * altitudeKm +
          2.0 * tmp +
          (a * a) * (1.0 - (1.0 - ba4) * sin2Lat) /
              (1.0 - (1.0 - ba2) * sin2Lat),
    );

    double sinColat = sin(colatRad);
    final cosColat = cos(colatRad);
    if (sinColat.abs() < 1e-12) {
      sinColat = sinColat >= 0 ? 1e-12 : -1e-12;
    }

    // 3. Polinomial Legendre Terkait (Schmidt semi-normalized)
    final p = List.generate(
      clampedDegree + 1,
      (_) => List.filled(clampedDegree + 1, 0.0),
    );
    final dp = List.generate(
      clampedDegree + 1,
      (_) => List.filled(clampedDegree + 1, 0.0),
    );
    final s = List.generate(
      clampedDegree + 1,
      (_) => List.filled(clampedDegree + 1, 0.0),
    );

    p[0][0] = 1.0;
    dp[0][0] = 0.0;
    s[0][0] = 1.0;

    for (int n = 1; n <= clampedDegree; n++) {
      for (int m = 0; m <= n; m++) {
        if (n == m) {
          p[n][n] = sinColat * p[n - 1][n - 1];
          dp[n][n] = sinColat * dp[n - 1][n - 1] + cosColat * p[n - 1][n - 1];
        } else {
          if (n == 1) {
            p[n][m] = cosColat * p[n - 1][m];
            dp[n][m] = -sinColat * p[n - 1][m];
          } else {
            final knm = ((n - 1) * (n - 1) - m * m) /
                ((2 * n - 1) * (2 * n - 3));
            p[n][m] = cosColat * p[n - 1][m] - knm * p[n - 2][m];
            dp[n][m] = cosColat * dp[n - 1][m] -
                sinColat * p[n - 1][m] -
                knm * dp[n - 2][m];
          }
        }

        // Faktor normalisasi Schmidt
        if (m == 0) {
          s[n][0] = s[n - 1][0] * (2.0 * n - 1.0) / n;
        } else {
          final factor = m == 1 ? 2.0 : 1.0;
          s[n][m] = s[n][m - 1] * sqrt((n - m + 1.0) * factor / (n + m));
        }
      }
    }

    // Terapkan faktor normalisasi Schmidt
    for (int n = 1; n <= clampedDegree; n++) {
      for (int m = 0; m <= n; m++) {
        p[n][m] *= s[n][m];
        dp[n][m] *= s[n][m];
      }
    }

    // 4. Akumulasi Komponen Medan Geosentrik
    final rho = earthRadiusKm / rKm;
    double rhoN = rho * rho; // (a/r)^2

    double bR = 0.0;
    double bTheta = 0.0;
    double bPhi = 0.0;

    for (int n = 1; n <= clampedDegree; n++) {
      rhoN *= rho; // (a/r)^(n+2)
      double sumR = 0.0;
      double sumTheta = 0.0;
      double sumPhi = 0.0;

      for (int m = 0; m <= n; m++) {
        final key = (n << 4) | m;
        final g = gMap[key] ?? 0.0;
        final h = hMap[key] ?? 0.0;

        final cosMPhi = cos(m * lonRad);
        final sinMPhi = sin(m * lonRad);

        final harm = g * cosMPhi + h * sinMPhi;
        final dHarm = -g * sinMPhi + h * cosMPhi;

        sumR += harm * p[n][m];
        sumTheta += harm * dp[n][m];
        sumPhi += m * dHarm * p[n][m];
      }

      bR += (n + 1) * rhoN * sumR;
      bTheta -= rhoN * sumTheta;
      bPhi -= (rhoN / sinColat) * sumPhi;
    }

    // 5. Transformasi dari Geosentrik ke Geodetik
    final psi = sinLat * sinColat - cosLat * cosColat;

    final bNorth = -cos(psi) * bTheta - sin(psi) * bR;
    final bUp = -sin(psi) * bTheta + cos(psi) * bR;
    final bDown = -bUp;
    final bEast = bPhi;

    final hHoriz = sqrt(bNorth * bNorth + bEast * bEast);
    final fTotal = sqrt(hHoriz * hHoriz + bDown * bDown);
    final declination = atan2(bEast, bNorth) * (180.0 / pi);
    final inclination = atan2(bDown, hHoriz) * (180.0 / pi);

    return IgrfResult(
      xNorthNt: bNorth,
      yEastNt: bEast,
      zDownNt: bDown,
      hHorizontalNt: hHoriz,
      fTotalNt: fTotal,
      declinationDeg: declination,
      inclinationDeg: inclination,
    );
  }

  /// Menghitung anomali medan total ΔT.
  ///
  /// Rumus:
  ///   ΔT = B_obs - B_diurnal - F_IGRF
  /// Jika koreksi diurnal bernilai null (misal survei tanpa base station):
  ///   ΔT = B_obs - F_IGRF
  double calculateDeltaTNt({
    required double observedTotalFieldNt,
    double? diurnalCorrectionNt,
    required double fIgrfNt,
  }) {
    final diurnal = diurnalCorrectionNt ?? 0.0;
    return observedTotalFieldNt - diurnal - fIgrfNt;
  }

  /// Menghitung IGRF, menghitung anomali ΔT, dan menyimpan ke tabel Anomalies di database Drift.
  Future<Anomaly> computeAndSaveAnomaly({
    required AppDatabase database,
    required String stationId,
    required double observedTotalFieldNt,
    double? diurnalCorrectionNt,
    required double latitudeDeg,
    required double longitudeDeg,
    double altitudeKm = 0.0,
    required DateTime date,
  }) async {
    final igrf = calculate(
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      altitudeKm: altitudeKm,
      date: date,
    );

    final deltaT = calculateDeltaTNt(
      observedTotalFieldNt: observedTotalFieldNt,
      diurnalCorrectionNt: diurnalCorrectionNt,
      fIgrfNt: igrf.fTotalNt,
    );

    final companion = AnomaliesCompanion.insert(
      id: 'anom-$stationId',
      stationId: stationId,
      fIgrfNt: Value(igrf.fTotalNt),
      diurnalCorrectionNt: Value(diurnalCorrectionNt),
      deltaTNt: Value(deltaT),
      calculatedAt: Value(DateTime.now()),
    );

    await database.into(database.anomalies).insertOnConflictUpdate(companion);

    return (await (database.select(database.anomalies)
          ..where((tbl) => tbl.stationId.equals(stationId)))
        .getSingle());
  }
}
