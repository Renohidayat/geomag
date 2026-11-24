import 'dart:math';

/// Hasil perhitungan Allan Deviation.
class AllanDeviationResult {
  final List<double> tauSeconds;
  final List<double> adev;
  final double noiseFloor;
  final double optimalTauSeconds;

  const AllanDeviationResult({
    required this.tauSeconds,
    required this.adev,
    required this.noiseFloor,
    required this.optimalTauSeconds,
  });

  @override
  String toString() {
    return 'AllanDeviationResult('
        'noiseFloor=${noiseFloor.toStringAsFixed(2)} nT, '
        'optimalTau=${optimalTauSeconds.toStringAsFixed(2)}s, '
        'numPoints=${tauSeconds.length})';
  }
}

/// Service untuk menghitung Allan Deviation dan menentukan lantai noise perangkat.
class AllanDeviationService {
  /// Menghitung Allan Deviation dari deret bacaan medan magnetik (dalam nT).
  ///
  /// Algoritma identik dengan implementasi referensi Python di `/reference/allan_deviation.py`.
  AllanDeviationResult computeAllanDeviation({
    required List<double> values,
    required double rateHz,
    int numTau = 20,
  }) {
    final n = values.length;
    if (n < 9) {
      throw ArgumentError(
        'Jumlah sampel terlalu sedikit untuk menghitung Allan deviation (minimal 9 sampel)',
      );
    }
    if (rateHz <= 0) {
      throw ArgumentError('Laju sampling rateHz harus positif');
    }

    final tau0 = 1.0 / rateHz;
    final maxM = max(2, n ~/ 3);

    // Buat rentang m logaritmik integer unik antara 1 dan maxM
    final mSet = <int>{};
    final effectiveNumTau = min(numTau, maxM);
    if (effectiveNumTau <= 1) {
      mSet.add(1);
    } else {
      for (var i = 0; i < effectiveNumTau; i++) {
        final fraction = i / (effectiveNumTau - 1);
        final logVal = 0.0 + fraction * (log(maxM) - 0.0);
        final m = max(1, exp(logVal).round());
        if (m <= maxM) {
          mSet.add(m);
        }
      }
    }

    final mValues = mSet.toList()..sort();
    final tauList = <double>[];
    final adevList = <double>[];

    for (final m in mValues) {
      final tau = m * tau0;
      final numClusters = n ~/ m;
      if (numClusters < 2) continue;

      // Hitung rata-rata tiap cluster (bin averaging)
      final clusterMeans = <double>[];
      for (var c = 0; c < numClusters; c++) {
        var sum = 0.0;
        final start = c * m;
        for (var k = 0; k < m; k++) {
          sum += values[start + k];
        }
        clusterMeans.add(sum / m);
      }

      // Selisih kuadrat antar cluster berturutan
      var sumSqDiff = 0.0;
      for (var i = 0; i < clusterMeans.length - 1; i++) {
        final diff = clusterMeans[i + 1] - clusterMeans[i];
        sumSqDiff += diff * diff;
      }

      final allanVar = 0.5 * (sumSqDiff / (clusterMeans.length - 1));
      final adev = sqrt(max(0.0, allanVar));

      tauList.add(tau);
      adevList.add(adev);
    }

    if (adevList.isEmpty) {
      throw StateError('Gagal menghitung titik Allan deviation');
    }

    var minIdx = 0;
    var minAdev = adevList[0];
    for (var i = 1; i < adevList.length; i++) {
      if (adevList[i] < minAdev) {
        minAdev = adevList[i];
        minIdx = i;
      }
    }

    return AllanDeviationResult(
      tauSeconds: tauList,
      adev: adevList,
      noiseFloor: minAdev,
      optimalTauSeconds: tauList[minIdx],
    );
  }
}
