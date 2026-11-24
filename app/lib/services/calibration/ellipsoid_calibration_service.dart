import 'dart:math';

import 'package:drift/drift.dart';
import 'package:geomag/database/app_database.dart';

/// Hasil kalibrasi ellipsoid.
class EllipsoidCalibrationResult {
  /// Offset hard-iron b [bx, by, bz] dalam mikroTesla.
  final List<double> offsetMicroT;

  /// Matriks transformasi koreksi 3x3 A (9 elemen baris-per-baris).
  final List<double> matrixA;

  /// Residu rata-rata (RMSE) terhadap B_ref dalam nT.
  final double residualNt;

  /// Simpangan baku magnitudo sebelum kalibrasi dalam nT.
  final double stdBeforeNt;

  /// Simpangan baku magnitudo sesudah kalibrasi dalam nT.
  final double stdAfterNt;

  /// Jumlah titik inlier yang digunakan setelah penolakan outlier.
  final int inlierCount;

  const EllipsoidCalibrationResult({
    required this.offsetMicroT,
    required this.matrixA,
    required this.residualNt,
    required this.stdBeforeNt,
    required this.stdAfterNt,
    required this.inlierCount,
  });

  /// Mengonversi matriks 3x3 ke string CSV (9 angka dipisah koma).
  String get matrixACsv => matrixA.map((v) => v.toStringAsFixed(8)).join(',');

  /// Mengoreksi satu sampel medan magnetik 3D mentah (mikroTesla)
  /// menghasilkan vektor terkoreksi [bx, by, bz] (mikroTesla).
  List<double> applyCorrection(double rawX, double rawY, double rawZ) {
    final dx = rawX - offsetMicroT[0];
    final dy = rawY - offsetMicroT[1];
    final dz = rawZ - offsetMicroT[2];

    final calX = matrixA[0] * dx + matrixA[1] * dy + matrixA[2] * dz;
    final calY = matrixA[3] * dx + matrixA[4] * dy + matrixA[5] * dz;
    final calZ = matrixA[6] * dx + matrixA[7] * dy + matrixA[8] * dz;

    return [calX, calY, calZ];
  }

  /// Menghitung magnitudo medan total terkoreksi dalam nanoTesla (nT).
  double calibratedTotalFieldNt(double rawX, double rawY, double rawZ) {
    final cal = applyCorrection(rawX, rawY, rawZ);
    final magMicroT = sqrt(cal[0] * cal[0] + cal[1] * cal[1] + cal[2] * cal[2]);
    return magMicroT * 1000.0;
  }
}

/// Kontrak antarmuka OOP untuk kalibrasi magnetometer ellipsoid
abstract class IEllipsoidCalibrationService {
  EllipsoidCalibrationResult fitEllipsoidRobust({
    required List<List<double>> pointsMicroT,
    required double bRefMicroT,
    int maxIter = 3,
    double outlierThresholdMad = 3.5,
  });

  Future<int> saveCalibrationProfile({
    required AppDatabase database,
    required String deviceId,
    required EllipsoidCalibrationResult result,
    double? temperatureC,
    bool casingAttached = false,
    Duration validDuration = const Duration(days: 30),
  });
}

/// Service kalibrasi magnetometer dengan fit ellipsoid robust.
///
/// Mengestimasi vektor hard iron b dan matriks koreksi soft iron A sehingga:
///     B_cal = A * (B_raw - b)
/// Algoritma identik dengan implementasi referensi Python di `/reference/ellipsoid_fit.py`.
class EllipsoidCalibrationService implements IEllipsoidCalibrationService {
  /// Melakukan fit ellipsoid robust pada sekumpulan titik bacaan 3D (mikroTesla).
  ///
  /// [pointsMicroT]: list titik 3D `[x, y, z]` dalam mikroTesla.
  /// [bRefMicroT]: magnitudo medan geomagnetik nominal referensi (misal 45.0 uT).
  /// [maxIter]: jumlah iterasi reweighting Huber (default 3).
  /// [outlierThresholdMad]: batas penolakan outlier dalam kelipatan MAD (default 3.5).
  @override
  EllipsoidCalibrationResult fitEllipsoidRobust({
    required List<List<double>> pointsMicroT,
    required double bRefMicroT,
    int maxIter = 3,
    double outlierThresholdMad = 3.5,
  }) {
    final n = pointsMicroT.length;
    if (n < 10) {
      throw ArgumentError(
        'Dibutuhkan minimal 10 titik orientasi untuk kalibrasi ellipsoid (tersedia: $n)',
      );
    }
    if (bRefMicroT <= 0) {
      throw ArgumentError('Medan referensi bRefMicroT harus bernilai positif');
    }

    // Pre-filtering awal: buang outlier ekstrim berdasarkan jarak terhadap pusat median
    final centerEst = _calculateMedianCenter(pointsMicroT);
    final dists = pointsMicroT.map((p) => _euclideanDist(p, centerEst)).toList();
    final dMed = _median(dists);
    final madDist = _median(dists.map((d) => (d - dMed).abs()).toList());
    final cutoffDist = max(3.0 * (1.4826 * madDist), 0.5 * dMed);

    final initialValid = dists.map((d) => (d - dMed).abs() <= cutoffDist).toList();
    final validCount = initialValid.where((v) => v).length;

    var weights = List<double>.filled(n, 1.0);
    if (validCount >= 10) {
      for (var i = 0; i < n; i++) {
        if (!initialValid[i]) weights[i] = 0.0;
      }
    }

    // Simpangan baku sebelum kalibrasi (dalam nT)
    final normsBeforeNt = pointsMicroT.map((p) {
      final mag = sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]);
      return mag * 1000.0;
    }).toList();
    final stdBeforeNt = _standardDeviation(normsBeforeNt);

    List<double> offset = [0.0, 0.0, 0.0];
    List<double> matrixA = [
      1.0, 0.0, 0.0,
      0.0, 1.0, 0.0,
      0.0, 0.0, 1.0,
    ];

    for (var iter = 0; iter < maxIter; iter++) {
      final p = _solveQuadricWls(pointsMicroT, weights);
      final calib = _paramsToCalibration(p, bRefMicroT);
      offset = calib.offset;
      matrixA = calib.matrixA;

      // Residu terhadap B_ref dalam nT
      final residualsNt = <double>[];
      for (var i = 0; i < n; i++) {
        final pt = pointsMicroT[i];
        final dx = pt[0] - offset[0];
        final dy = pt[1] - offset[1];
        final dz = pt[2] - offset[2];

        final cx = matrixA[0] * dx + matrixA[1] * dy + matrixA[2] * dz;
        final cy = matrixA[3] * dx + matrixA[4] * dy + matrixA[5] * dz;
        final cz = matrixA[6] * dx + matrixA[7] * dy + matrixA[8] * dz;

        final magMicroT = sqrt(cx * cx + cy * cy + cz * cz);
        residualsNt.add(((magMicroT - bRefMicroT) * 1000.0).abs());
      }

      // Skala robust MAD
      final medRes = _median(residualsNt);
      final mad = _median(residualsNt.map((r) => (r - medRes).abs()).toList());
      final sigmaMad = max(1.4826 * mad, 1e-3);

      final huberK = 1.5 * sigmaMad;
      final cutoff = outlierThresholdMad * sigmaMad;

      final newWeights = List<double>.filled(n, 1.0);
      for (var i = 0; i < n; i++) {
        final r = residualsNt[i];
        if (r > cutoff) {
          newWeights[i] = 0.0;
        } else if (r > huberK) {
          newWeights[i] = huberK / r;
        } else {
          newWeights[i] = 1.0;
        }
      }
      weights = newWeights;
    }

    // Evaluasi hasil akhir
    final normsAfterNt = <double>[];
    final inlierResidualsNt = <double>[];
    var inlierCount = 0;

    for (var i = 0; i < n; i++) {
      if (weights[i] > 0.0) {
        inlierCount++;
        final pt = pointsMicroT[i];
        final dx = pt[0] - offset[0];
        final dy = pt[1] - offset[1];
        final dz = pt[2] - offset[2];

        final cx = matrixA[0] * dx + matrixA[1] * dy + matrixA[2] * dz;
        final cy = matrixA[3] * dx + matrixA[4] * dy + matrixA[5] * dz;
        final cz = matrixA[6] * dx + matrixA[7] * dy + matrixA[8] * dz;

        final magNt = sqrt(cx * cx + cy * cy + cz * cz) * 1000.0;
        normsAfterNt.add(magNt);
        final res = (magNt - (bRefMicroT * 1000.0)).abs();
        inlierResidualsNt.add(res);
      }
    }

    if (inlierCount == 0) {
      for (var i = 0; i < n; i++) {
        final pt = pointsMicroT[i];
        final dx = pt[0] - offset[0];
        final dy = pt[1] - offset[1];
        final dz = pt[2] - offset[2];

        final cx = matrixA[0] * dx + matrixA[1] * dy + matrixA[2] * dz;
        final cy = matrixA[3] * dx + matrixA[4] * dy + matrixA[5] * dz;
        final cz = matrixA[6] * dx + matrixA[7] * dy + matrixA[8] * dz;

        final magNt = sqrt(cx * cx + cy * cy + cz * cz) * 1000.0;
        normsAfterNt.add(magNt);
        inlierResidualsNt.add((magNt - (bRefMicroT * 1000.0)).abs());
      }
      inlierCount = n;
    }

    var sumSqRes = 0.0;
    for (final r in inlierResidualsNt) {
      sumSqRes += r * r;
    }
    final residualRmseNt = sqrt(sumSqRes / inlierResidualsNt.length);
    final stdAfterNt = _standardDeviation(normsAfterNt);

    return EllipsoidCalibrationResult(
      offsetMicroT: offset,
      matrixA: matrixA,
      residualNt: residualRmseNt,
      stdBeforeNt: stdBeforeNt,
      stdAfterNt: stdAfterNt,
      inlierCount: inlierCount,
    );
  }

  /// Menyimpan profil kalibrasi ke tabel `CalibrationProfiles` database Drift.
  @override
  Future<int> saveCalibrationProfile({
    required AppDatabase database,
    required String deviceId,
    required EllipsoidCalibrationResult result,
    double? temperatureC,
    bool casingAttached = false,
    Duration validDuration = const Duration(days: 30),
  }) async {
    final now = DateTime.now();
    final profileId = 'cal_${now.millisecondsSinceEpoch}';

    return await database.insertCalibrationProfile(
      CalibrationProfilesCompanion(
        id: Value(profileId),
        deviceId: Value(deviceId),
        timestamp: Value(now),
        hardIronBxMicroT: Value(result.offsetMicroT[0]),
        hardIronByMicroT: Value(result.offsetMicroT[1]),
        hardIronBzMicroT: Value(result.offsetMicroT[2]),
        matrixA: Value(result.matrixACsv),
        temperatureC: Value(temperatureC),
        casingAttached: Value(casingAttached),
        residualNt: Value(result.residualNt),
        expiresAt: Value(now.add(validDuration)),
        createdAt: Value(now),
      ),
    );
  }

  // --- Operasi Matriks dan Aljabar Linier ---

  /// Menyelesaikan (D^T * W * D) * p = D^T * W * Y
  List<double> _solveQuadricWls(
    List<List<double>> points,
    List<double> weights,
  ) {
    // Matriks normal 9x9 DtWD dan vektor 9 DtWY
    final ata = List.generate(9, (_) => List<double>.filled(9, 0.0));
    final aty = List<double>.filled(9, 0.0);

    final row = List<double>.filled(9, 0.0);

    for (var k = 0; k < points.length; k++) {
      final w = weights[k];
      if (w <= 0.0) continue;
      final wSq = w * w;

      final x = points[k][0];
      final y = points[k][1];
      final z = points[k][2];

      row[0] = x * x;
      row[1] = y * y;
      row[2] = z * z;
      row[3] = 2.0 * x * y;
      row[4] = 2.0 * x * z;
      row[5] = 2.0 * y * z;
      row[6] = 2.0 * x;
      row[7] = 2.0 * y;
      row[8] = 2.0 * z;

      for (var i = 0; i < 9; i++) {
        final wSqRowI = wSq * row[i];
        for (var j = 0; j < 9; j++) {
          ata[i][j] += wSqRowI * row[j];
        }
        aty[i] += wSqRowI; // karena rhs Y = 1.0
      }
    }

    return _solveLinearSystem(ata, aty);
  }

  /// Ekstraksi offset dan matriks transformasi dari kuadrik p = [a..i].
  ({List<double> offset, List<double> matrixA}) _paramsToCalibration(
    List<double> p,
    double bRefMicroT,
  ) {
    final a = p[0], b = p[1], c = p[2];
    final d = p[3], e = p[4], f = p[5];
    final g = p[6], h = p[7], i = p[8];

    // Matriks kuadrik 3x3
    final aQuad = [
      [a, d, e],
      [d, b, f],
      [e, f, c],
    ];

    final bQuad = [g, h, i];

    // v_offset = -A_quad^(-1) * b_quad
    final offset = _solve3x3(aQuad, [-bQuad[0], -bQuad[1], -bQuad[2]]);

    // k = 1 + offset^T * A_quad * offset
    final quadOffset = [
      aQuad[0][0] * offset[0] + aQuad[0][1] * offset[1] + aQuad[0][2] * offset[2],
      aQuad[1][0] * offset[0] + aQuad[1][1] * offset[1] + aQuad[1][2] * offset[2],
      aQuad[2][0] * offset[0] + aQuad[2][1] * offset[1] + aQuad[2][2] * offset[2],
    ];
    final k = 1.0 +
        (offset[0] * quadOffset[0] +
            offset[1] * quadOffset[1] +
            offset[2] * quadOffset[2]);

    if (k <= 0) {
      throw StateError('Parameter kuadrik tidak membentuk ellipsoid nyata');
    }

    // Matriks M = A_quad / k
    final mMat = List.generate(
      3,
      (row) => List.generate(3, (col) => aQuad[row][col] / k),
    );

    // Dekomposisi nilai eigen simetris M = V * diag(eigenvals) * V^T
    final eigen = _jacobiEigen3x3(mMat);
    for (final val in eigen.values) {
      if (val <= 0) {
        throw StateError('Matriks ellipsoid tidak definit positif');
      }
    }

    // M^(1/2) = V * diag(sqrt(vals)) * V^T
    final sqrtVals = eigen.values.map(sqrt).toList();
    final v = eigen.vectors;

    // V * diag(sqrtVals)
    final vDiag = List.generate(
      3,
      (r) => List.generate(3, (c) => v[r][c] * sqrtVals[c]),
    );

    // (V * diag(sqrtVals)) * V^T
    final mSqrt = List.generate(
      3,
      (r) => List.generate(
        3,
        (c) =>
            vDiag[r][0] * v[c][0] +
            vDiag[r][1] * v[c][1] +
            vDiag[r][2] * v[c][2],
      ),
    );

    // A = bRef * M^(1/2) (flattened 9 elemen)
    final matrixA = <double>[
      bRefMicroT * mSqrt[0][0], bRefMicroT * mSqrt[0][1], bRefMicroT * mSqrt[0][2],
      bRefMicroT * mSqrt[1][0], bRefMicroT * mSqrt[1][1], bRefMicroT * mSqrt[1][2],
      bRefMicroT * mSqrt[2][0], bRefMicroT * mSqrt[2][1], bRefMicroT * mSqrt[2][2],
    ];

    return (offset: offset, matrixA: matrixA);
  }

  /// Eliminasi Gauss dengan partial pivoting untuk matriks umum NxN.
  List<double> _solveLinearSystem(List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = List.generate(n, (i) => List<double>.from(a[i]));
    final x = List<double>.from(b);

    for (var i = 0; i < n; i++) {
      // Cari pivot terbesar
      var maxRow = i;
      var maxVal = m[i][i].abs();
      for (var k = i + 1; k < n; k++) {
        if (m[k][i].abs() > maxVal) {
          maxVal = m[k][i].abs();
          maxRow = k;
        }
      }

      if (maxVal < 1e-14) {
        throw StateError('Matriks singular dalam penyelesaian sistem linear');
      }

      // Tukar baris
      if (maxRow != i) {
        final tempRow = m[i];
        m[i] = m[maxRow];
        m[maxRow] = tempRow;

        final tempB = x[i];
        x[i] = x[maxRow];
        x[maxRow] = tempB;
      }

      // Eliminasi
      for (var k = i + 1; k < n; k++) {
        final factor = m[k][i] / m[i][i];
        x[k] -= factor * x[i];
        for (var j = i; j < n; j++) {
          m[k][j] -= factor * m[i][j];
        }
      }
    }

    // Back substitution
    final sol = List<double>.filled(n, 0.0);
    for (var i = n - 1; i >= 0; i--) {
      var sum = x[i];
      for (var j = i + 1; j < n; j++) {
        sum -= m[i][j] * sol[j];
      }
      sol[i] = sum / m[i][i];
    }

    return sol;
  }

  /// Inversi sistem 3x3 eksak dengan aturan Cramer.
  List<double> _solve3x3(List<List<double>> a, List<double> b) {
    final det = a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) -
        a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
        a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]);

    if (det.abs() < 1e-14) {
      throw StateError('Determinan matriks kuadrik mendekati nol');
    }

    final invDet = 1.0 / det;

    final x0 = invDet *
        (b[0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) -
            a[0][1] * (b[1] * a[2][2] - a[1][2] * b[2]) +
            a[0][2] * (b[1] * a[2][1] - a[1][1] * b[2]));

    final x1 = invDet *
        (a[0][0] * (b[1] * a[2][2] - a[1][2] * b[2]) -
            b[0] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
            a[0][2] * (a[1][0] * b[2] - b[1] * a[2][0]));

    final x2 = invDet *
        (a[0][0] * (a[1][1] * b[2] - b[1] * a[2][1]) -
            a[0][1] * (a[1][0] * b[2] - b[1] * a[2][0]) +
            b[0] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]));

    return [x0, x1, x2];
  }

  /// Algoritma Jacobi Eigenvalue untuk matriks simetris 3x3.
  /// Mengembalikan nilai eigen dan matriks vektor eigen ortogonal V.
  ({List<double> values, List<List<double>> vectors}) _jacobiEigen3x3(
    List<List<double>> aIn,
  ) {
    final a = List.generate(3, (i) => List<double>.from(aIn[i]));
    final v = [
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
      [0.0, 0.0, 1.0],
    ];

    const maxSweeps = 50;
    const eps = 1e-15;

    for (var sweep = 0; sweep < maxSweeps; sweep++) {
      // Periksa magnitudo elemen off-diagonal
      final offDiag = a[0][1].abs() + a[0][2].abs() + a[1][2].abs();
      if (offDiag < eps) break;

      for (var p = 0; p < 2; p++) {
        for (var q = p + 1; q < 3; q++) {
          final apq = a[p][q];
          if (apq.abs() < eps) continue;

          final app = a[p][p];
          final aqq = a[q][q];
          final theta = 0.5 * (aqq - app) / apq;
          final t = (theta >= 0)
              ? 1.0 / (theta + sqrt(1.0 + theta * theta))
              : -1.0 / (-theta + sqrt(1.0 + theta * theta));
          final c = 1.0 / sqrt(1.0 + t * t);
          final s = t * c;
          final tau = s / (1.0 + c);

          a[p][p] = app - t * apq;
          a[q][q] = aqq + t * apq;
          a[p][q] = 0.0;
          a[q][p] = 0.0;

          for (var r = 0; r < 3; r++) {
            if (r != p && r != q) {
              final arp = a[r][p];
              final arq = a[r][q];
              a[r][p] = arp - s * (arq + tau * arp);
              a[p][r] = a[r][p];
              a[r][q] = arq + s * (arp - tau * arq);
              a[q][r] = a[r][q];
            }
          }

          // Akumulasi rotasi ke matriks vektor eigen V
          for (var r = 0; r < 3; r++) {
            final vrp = v[r][p];
            final vrq = v[r][q];
            v[r][p] = vrp - s * (vrq + tau * vrp);
            v[r][q] = vrq + s * (vrp - tau * vrq);
          }
        }
      }
    }

    final values = [a[0][0], a[1][1], a[2][2]];
    return (values: values, vectors: v);
  }

  // --- Statistik Helper ---

  List<double> _calculateMedianCenter(List<List<double>> points) {
    final xs = points.map((p) => p[0]).toList()..sort();
    final ys = points.map((p) => p[1]).toList()..sort();
    final zs = points.map((p) => p[2]).toList()..sort();
    return [_medianSorted(xs), _medianSorted(ys), _medianSorted(zs)];
  }

  double _euclideanDist(List<double> a, List<double> b) {
    final dx = a[0] - b[0];
    final dy = a[1] - b[1];
    final dz = a[2] - b[2];
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    return _medianSorted(sorted);
  }

  double _medianSorted(List<double> sorted) {
    final n = sorted.length;
    if (n == 0) return 0.0;
    if (n % 2 == 1) {
      return sorted[n ~/ 2];
    } else {
      return 0.5 * (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]);
    }
  }

  double _standardDeviation(List<double> values) {
    if (values.length <= 1) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    var sumSq = 0.0;
    for (final v in values) {
      final diff = v - mean;
      sumSq += diff * diff;
    }
    return sqrt(sumSq / (values.length - 1));
  }
}
