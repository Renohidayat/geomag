import 'dart:math';

/// Titik data pada sebuah lintasan survei.
class SurveyLinePoint {
  /// Koordinat lokal X atau UTM Easting (meter).
  final double x;

  /// Koordinat lokal Y atau UTM Northing (meter).
  final double y;

  /// Nilai pembacaan medan magnetik (nT), misal anomali ΔT atau medan terkoreksi diurnal.
  final double readingNt;

  /// ID stasiun opsional untuk pelacakan relasional ke database.
  final String? stationId;

  const SurveyLinePoint({
    required this.x,
    required this.y,
    required this.readingNt,
    this.stationId,
  });
}

/// Lintasan survei magnetik (survey line atau tie line).
class SurveyLine {
  /// Identifikasi lintasan (misal 'L1', 'L2', 'T1').
  final String lineId;

  /// Tipe lintasan: 'survey' atau 'tie'.
  final String lineType;

  /// Titik-titik stasiun sepanjang lintasan (terurut).
  final List<SurveyLinePoint> points;

  const SurveyLine({
    required this.lineId,
    required this.lineType,
    required this.points,
  });
}

/// Titik perpotongan antara survey line dan tie line.
class CrossoverPoint {
  final String surveyLineId;
  final String tieLineId;
  final double x;
  final double y;
  final double bSurveyNt;
  final double bTieNt;
  final double errorNt; // bSurveyNt - bTieNt
  final double? residualNt; // setelah koreksi levelling diterapkan

  const CrossoverPoint({
    required this.surveyLineId,
    required this.tieLineId,
    required this.x,
    required this.y,
    required this.bSurveyNt,
    required this.bTieNt,
    required this.errorNt,
    this.residualNt,
  });
}

/// Hasil evaluasi koreksi tie-line levelling.
class LevellingResult {
  final bool isSuccessful;
  final int crossoverCount;
  final double rmseBeforeNt;
  final double rmseAfterNt;
  final Map<String, double> lineCorrections;
  final List<CrossoverPoint> crossovers;
  final List<SurveyLine> levelledLines;

  const LevellingResult({
    required this.isSuccessful,
    required this.crossoverCount,
    required this.rmseBeforeNt,
    required this.rmseAfterNt,
    required this.lineCorrections,
    required this.crossovers,
    required this.levelledLines,
  });
}

/// Service fungsi murni untuk koreksi levelling lintasan survei geomagnetik.
///
/// Menggunakan formulasi kuadrat terkecil teratur (regularized least squares):
///   (G^T G + λ I) c = G^T ε
class LevellingService {
  const LevellingService();

  /// Mencari titik perpotongan antara segmen garis p1-p2 dan q1-q2.
  ///
  /// Mengembalikan (x, y, u, v) jika berpotongan di dalam segmen, atau null jika tidak.
  ({double x, double y, double u, double v})? findSegmentIntersection(
    SurveyLinePoint p1,
    SurveyLinePoint p2,
    SurveyLinePoint q1,
    SurveyLinePoint q2,
  ) {
    final dx1 = p2.x - p1.x;
    final dy1 = p2.y - p1.y;
    final dx2 = q2.x - q1.x;
    final dy2 = q2.y - q1.y;

    final det = dx1 * dy2 - dy1 * dx2;
    if (det.abs() < 1e-12) {
      return null; // Garis sejajar atau kolinier
    }

    final xDiff = q1.x - p1.x;
    final yDiff = q1.y - p1.y;

    final u = (xDiff * dy2 - yDiff * dx2) / det;
    final v = (xDiff * dy1 - yDiff * dx1) / det;

    const eps = 1e-6;
    if (u >= -eps && u <= 1.0 + eps && v >= -eps && v <= 1.0 + eps) {
      final uClamped = u.clamp(0.0, 1.0);
      final vClamped = v.clamp(0.0, 1.0);
      final x = p1.x + uClamped * dx1;
      final y = p1.y + uClamped * dy1;
      return (x: x, y: y, u: uClamped, v: vClamped);
    }

    return null;
  }

  /// Menghitung seluruh titik perpotongan antara survey lines dan tie lines.
  List<CrossoverPoint> calculateCrossovers(List<SurveyLine> lines) {
    final surveyLines = lines.where((l) => l.lineType == 'survey').toList();
    final tieLines = lines.where((l) => l.lineType == 'tie').toList();

    final crossovers = <CrossoverPoint>[];

    for (final sLine in surveyLines) {
      for (final tLine in tieLines) {
        final sPts = sLine.points;
        final tPts = tLine.points;

        for (int i = 0; i < sPts.length - 1; i++) {
          final p1 = sPts[i];
          final p2 = sPts[i + 1];

          for (int j = 0; j < tPts.length - 1; j++) {
            final q1 = tPts[j];
            final q2 = tPts[j + 1];

            final inter = findSegmentIntersection(p1, p2, q1, q2);
            if (inter != null) {
              final bSurvey =
                  p1.readingNt + inter.u * (p2.readingNt - p1.readingNt);
              final bTie =
                  q1.readingNt + inter.v * (q2.readingNt - q1.readingNt);

              crossovers.add(
                CrossoverPoint(
                  surveyLineId: sLine.lineId,
                  tieLineId: tLine.lineId,
                  x: inter.x,
                  y: inter.y,
                  bSurveyNt: bSurvey,
                  bTieNt: bTie,
                  errorNt: bSurvey - bTie,
                ),
              );
            }
          }
        }
      }
    }

    return crossovers;
  }

  /// Melakukan koreksi levelling kuadrat terkecil untuk menentukan bias per lintasan.
  LevellingResult performLevelling(
    List<SurveyLine> lines, {
    double damping = 1e-4,
  }) {
    final crossovers = calculateCrossovers(lines);
    if (crossovers.isEmpty) {
      return LevellingResult(
        isSuccessful: false,
        crossoverCount: 0,
        rmseBeforeNt: 0.0,
        rmseAfterNt: 0.0,
        lineCorrections: {for (final l in lines) l.lineId: 0.0},
        crossovers: const [],
        levelledLines: lines,
      );
    }

    // Identifikasi lintasan unik yang memiliki perpotongan
    final sLineIds = crossovers.map((c) => c.surveyLineId).toSet().toList()
      ..sort();
    final tLineIds = crossovers.map((c) => c.tieLineId).toSet().toList()
      ..sort();

    final ns = sLineIds.length;
    final nt = tLineIds.length;
    final totalParams = ns + nt;

    final sIdxMap = {for (int i = 0; i < ns; i++) sLineIds[i]: i};
    final tIdxMap = {for (int i = 0; i < nt; i++) tLineIds[i]: ns + i};

    final k = crossovers.length;

    // Matriks G (k x totalParams) dan vektor epsilon (k x 1)
    final g = List.generate(k, (_) => List.filled(totalParams, 0.0));
    final eps = List.filled(k, 0.0);

    for (int row = 0; row < k; row++) {
      final c = crossovers[row];
      final sCol = sIdxMap[c.surveyLineId]!;
      final tCol = tIdxMap[c.tieLineId]!;
      g[row][sCol] = 1.0;
      g[row][tCol] = -1.0;
      eps[row] = c.errorNt;
    }

    // Bangun sistem persamaan normal: A * c = b
    // A = G^T * G + damping * I (totalParams x totalParams)
    // b = G^T * eps (totalParams x 1)
    final a = List.generate(
      totalParams,
      (_) => List.filled(totalParams, 0.0),
    );
    final b = List.filled(totalParams, 0.0);

    for (int i = 0; i < totalParams; i++) {
      for (int j = 0; j < totalParams; j++) {
        double sum = 0.0;
        for (int r = 0; r < k; r++) {
          sum += g[r][i] * g[r][j];
        }
        if (i == j) {
          sum += damping;
        }
        a[i][j] = sum;
      }

      double sumB = 0.0;
      for (int r = 0; r < k; r++) {
        sumB += g[r][i] * eps[r];
      }
      b[i] = sumB;
    }

    // Selesaikan sistem linear via eliminasi Gauss dengan partial pivoting
    final correctionsVec = _solveLinearSystem(a, b);

    final corrections = <String, double>{};
    for (final entry in sIdxMap.entries) {
      corrections[entry.key] = correctionsVec[entry.value];
    }
    for (final entry in tIdxMap.entries) {
      corrections[entry.key] = correctionsVec[entry.value];
    }

    // Isi 0.0 untuk lintasan tanpa perpotongan
    for (final l in lines) {
      corrections.putIfAbsent(l.lineId, () => 0.0);
    }

    // Evaluasi RMSE sebelum dan setelah koreksi
    double sqErrBefore = 0.0;
    double sqErrAfter = 0.0;

    final updatedCrossovers = <CrossoverPoint>[];
    for (final c in crossovers) {
      final cSurvey = corrections[c.surveyLineId]!;
      final cTie = corrections[c.tieLineId]!;
      final res = (c.bSurveyNt - cSurvey) - (c.bTieNt - cTie);

      sqErrBefore += c.errorNt * c.errorNt;
      sqErrAfter += res * res;

      updatedCrossovers.add(
        CrossoverPoint(
          surveyLineId: c.surveyLineId,
          tieLineId: c.tieLineId,
          x: c.x,
          y: c.y,
          bSurveyNt: c.bSurveyNt,
          bTieNt: c.bTieNt,
          errorNt: c.errorNt,
          residualNt: res,
        ),
      );
    }

    final rmseBefore = sqrt(sqErrBefore / k);
    final rmseAfter = sqrt(sqErrAfter / k);

    // Terapkan pergeseran koreksi ke semua titik lintasan
    final levelledLines = <SurveyLine>[];
    for (final l in lines) {
      final corr = corrections[l.lineId] ?? 0.0;
      final newPts = l.points
          .map((p) => SurveyLinePoint(
                x: p.x,
                y: p.y,
                readingNt: p.readingNt - corr,
                stationId: p.stationId,
              ))
          .toList();

      levelledLines.add(
        SurveyLine(
          lineId: l.lineId,
          lineType: l.lineType,
          points: newPts,
        ),
      );
    }

    return LevellingResult(
      isSuccessful: true,
      crossoverCount: k,
      rmseBeforeNt: rmseBefore,
      rmseAfterNt: rmseAfter,
      lineCorrections: corrections,
      crossovers: updatedCrossovers,
      levelledLines: levelledLines,
    );
  }

  /// Solusi numerik sistem linier A * x = b dengan eliminasi Gauss partial pivoting.
  List<double> _solveLinearSystem(List<List<double>> aIn, List<double> bIn) {
    final n = bIn.length;
    final a = List.generate(n, (i) => List<double>.from(aIn[i]));
    final b = List<double>.from(bIn);

    for (int col = 0; col < n; col++) {
      int maxRow = col;
      double maxVal = a[col][col].abs();

      for (int row = col + 1; row < n; row++) {
        final val = a[row][col].abs();
        if (val > maxVal) {
          maxVal = val;
          maxRow = row;
        }
      }

      if (maxRow != col) {
        final tempRow = a[col];
        a[col] = a[maxRow];
        a[maxRow] = tempRow;

        final tempB = b[col];
        b[col] = b[maxRow];
        b[maxRow] = tempB;
      }

      final pivot = a[col][col];
      if (pivot.abs() < 1e-15) continue;

      for (int row = col + 1; row < n; row++) {
        final factor = a[row][col] / pivot;
        a[row][col] = 0.0;
        for (int c = col + 1; c < n; c++) {
          a[row][c] -= factor * a[col][c];
        }
        b[row] -= factor * b[col];
      }
    }

    // Back substitution
    final x = List.filled(n, 0.0);
    for (int row = n - 1; row >= 0; row--) {
      double sum = b[row];
      for (int col = row + 1; col < n; col++) {
        sum -= a[row][col] * x[col];
      }
      final diag = a[row][row];
      x[row] = diag.abs() > 1e-15 ? sum / diag : 0.0;
    }

    return x;
  }
}
