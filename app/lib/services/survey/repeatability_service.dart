import 'dart:math';

/// Metrik hasil evaluasi keterulangan dan konsistensi antar-profil survei geomagnetik.
class RepeatabilityMetrics {
  /// Jumlah titik stasiun / sampel yang dibandingkan.
  final int sampleCount;

  /// Selisih absolut rata-rata antar stasiun berpasangan (|mean diff| nT).
  final double meanAbsoluteDiffNt;

  /// Selisih rata-rata berarah (bias/drift rata-rata A - B nT).
  final double meanDiffNt;

  /// Root Mean Square Error selisih profil (RMSE nT).
  final double rmseNt;

  /// Selisih absolut terbesar antar-titik (max |diff| nT).
  final double maxAbsoluteDiffNt;

  /// Koefisien korelasi Pearson (r) bentuk gelombang profil (-1.0 s.d. +1.0).
  final double pearsonR;

  /// Batas ambang toleransi yang diizinkan (biasanya 2x lantai noise nT).
  final double toleranceLimitNt;

  /// Rasio titik yang memenuhi batas toleransi (0.0 s.d. 1.0).
  final double withinToleranceRatio;

  /// Status kesimpulan apakah kedua profil konsisten sesuai kriteria PRD.
  final bool isConsistent;

  /// Daftar selisih pasangan nilai per stasiun (A - B nT).
  final List<double> pairedDifferences;

  const RepeatabilityMetrics({
    required this.sampleCount,
    required this.meanAbsoluteDiffNt,
    required this.meanDiffNt,
    required this.rmseNt,
    required this.maxAbsoluteDiffNt,
    required this.pearsonR,
    required this.toleranceLimitNt,
    required this.withinToleranceRatio,
    required this.isConsistent,
    required this.pairedDifferences,
  });

  /// Ringkasan laporan evaluasi keterulangan.
  String toSummaryText() {
    final pctWithin = (withinToleranceRatio * 100).toStringAsFixed(1);
    final status = isConsistent ? 'KONSISTEN (LULUS)' : 'TIDAK KONSISTEN (GAGAL)';
    return '''
=== LAPORAN EVALUASI KETERULANGAN SURVEI ===
Status: $status
Jumlah Titik: $sampleCount
Toleransi Ambang: ${toleranceLimitNt.toStringAsFixed(1)} nT
Beda Rata-rata (Bias): ${meanDiffNt.toStringAsFixed(2)} nT
Beda Absolut Rata-rata (MAD): ${meanAbsoluteDiffNt.toStringAsFixed(2)} nT
Beda Kuadrat Rata-rata (RMSE): ${rmseNt.toStringAsFixed(2)} nT
Beda Maksimum: ${maxAbsoluteDiffNt.toStringAsFixed(2)} nT
Korelasi Pearson (r): ${pearsonR.toStringAsFixed(4)}
Titik Lolos Toleransi: $pctWithin%
===========================================
''';
  }
}

/// Layanan murni untuk menganalisis keterulangan dan konsistensi profil survei geomagnetik
/// (komparasi multi-smartphone, repeat station, loop survey, atau validasi instrumen pembanding).
class RepeatabilityAnalysisService {
  const RepeatabilityAnalysisService();

  /// Menghitung metrik keterulangan profil A terhadap profil B.
  ///
  /// Melempar [ArgumentError] jika panjang [seriesA] dan [seriesB] berbeda atau kosong.
  RepeatabilityMetrics computeMetrics({
    required List<double> seriesA,
    required List<double> seriesB,
    double noiseFloorNt = 500.0,
    double toleranceMultiplier = 2.0,
    double minCorrelation = 0.85,
  }) {
    final nA = seriesA.length;
    final nB = seriesB.length;

    if (nA != nB) {
      throw ArgumentError(
        'Panjang kedua profil harus sama! Profil A=$nA, Profil B=$nB',
      );
    }
    if (nA == 0) {
      throw ArgumentError('Profil survei tidak boleh kosong!');
    }

    final diffs = List<double>.generate(nA, (i) => seriesA[i] - seriesB[i]);
    final absDiffs = diffs.map((d) => d.abs()).toList();

    var sumAbsDiff = 0.0;
    var sumDiff = 0.0;
    var sumSqDiff = 0.0;
    var maxAbs = 0.0;

    for (var i = 0; i < nA; i++) {
      final d = diffs[i];
      final absD = absDiffs[i];
      sumDiff += d;
      sumAbsDiff += absD;
      sumSqDiff += d * d;
      if (absD > maxAbs) {
        maxAbs = absD;
      }
    }

    final meanAbsDiff = sumAbsDiff / nA;
    final meanDiff = sumDiff / nA;
    final rmse = sqrt(sumSqDiff / nA);

    final toleranceLimit = toleranceMultiplier * noiseFloorNt;
    var withinCount = 0;
    for (final ad in absDiffs) {
      if (ad <= toleranceLimit) {
        withinCount++;
      }
    }
    final withinRatio = withinCount / nA;

    // Perhitungan Korelasi Pearson (r)
    double pearsonR;
    double stdA = 0.0;
    if (nA < 2) {
      pearsonR = (seriesA[0] - seriesB[0]).abs() < 1e-6 ? 1.0 : 0.0;
    } else {
      var sumA = 0.0;
      var sumB = 0.0;
      for (var i = 0; i < nA; i++) {
        sumA += seriesA[i];
        sumB += seriesB[i];
      }
      final meanA = sumA / nA;
      final meanB = sumB / nA;

      var varA = 0.0;
      var varB = 0.0;
      var cov = 0.0;
      for (var i = 0; i < nA; i++) {
        final da = seriesA[i] - meanA;
        final db = seriesB[i] - meanB;
        varA += da * da;
        varB += db * db;
        cov += da * db;
      }
      varA /= nA;
      varB /= nA;
      cov /= nA;
      stdA = sqrt(varA);
      final stdB = sqrt(varB);

      if (varA < 1e-12 || varB < 1e-12) {
        var allClose = true;
        for (var i = 0; i < nA; i++) {
          if ((seriesA[i] - seriesB[i]).abs() > 1e-6) {
            allClose = false;
            break;
          }
        }
        pearsonR = allClose ? 1.0 : 0.0;
      } else {
        final rawR = cov / (stdA * stdB);
        pearsonR = rawR.clamp(-1.0, 1.0);
      }
    }

    // Kriteria konsistensi sesuai PRD:
    // 1. Minimal 90% titik berada di dalam batas toleransi (<= 2x lantai noise)
    // 2. RMSE <= batas toleransi
    // 3. Bentuk profil konsisten (r >= minCorrelation jika ada variasi anomali)
    final isProfileCorrelated =
        pearsonR >= minCorrelation || stdA < noiseFloorNt;
    final isConsistent =
        withinRatio >= 0.90 && rmse <= toleranceLimit && isProfileCorrelated;

    return RepeatabilityMetrics(
      sampleCount: nA,
      meanAbsoluteDiffNt: meanAbsDiff,
      meanDiffNt: meanDiff,
      rmseNt: rmse,
      maxAbsoluteDiffNt: maxAbs,
      pearsonR: pearsonR,
      toleranceLimitNt: toleranceLimit,
      withinToleranceRatio: withinRatio,
      isConsistent: isConsistent,
      pairedDifferences: diffs,
    );
  }
}
