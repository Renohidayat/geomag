import 'dart:math';

/// Hasil analisis diagnostik timing magnetometer.
class SensorTimingAnalysis {
  final int sampleCount;
  final double durationSeconds;
  final double actualRateHz;
  final double avgIntervalMs;
  final double jitterMs;
  final double minIntervalMs;
  final double maxIntervalMs;
  final int gapCount;
  final double screenOnRateHz;
  final double screenOffRateHz;

  const SensorTimingAnalysis({
    required this.sampleCount,
    required this.durationSeconds,
    required this.actualRateHz,
    required this.avgIntervalMs,
    required this.jitterMs,
    required this.minIntervalMs,
    required this.maxIntervalMs,
    required this.gapCount,
    required this.screenOnRateHz,
    required this.screenOffRateHz,
  });

  @override
  String toString() {
    return 'SensorTimingAnalysis('
        'n=$sampleCount, '
        'rate=${actualRateHz.toStringAsFixed(1)}Hz, '
        'interval=${avgIntervalMs.toStringAsFixed(2)}ms, '
        'jitter=${jitterMs.toStringAsFixed(2)}ms, '
        'gaps=$gapCount, '
        'screenOnRate=${screenOnRateHz.toStringAsFixed(1)}Hz, '
        'screenOffRate=${screenOffRateHz.toStringAsFixed(1)}Hz)';
  }
}

/// Service untuk memverifikasi laju sampling nyata, jitter, dan perilaku layar mati.
class SensorDiagnosticsService {
  /// Menganalisis daftar timestamp nanodetik dan status layar.
  /// Menghasilkan metrik statistik yang sama dengan implementasi referensi Python.
  SensorTimingAnalysis analyzeTiming({
    required List<int> timestampsNs,
    List<bool>? screenStates,
    double gapThresholdFactor = 2.0,
  }) {
    final n = timestampsNs.length;
    if (n < 2) {
      return const SensorTimingAnalysis(
        sampleCount: 0,
        durationSeconds: 0.0,
        actualRateHz: 0.0,
        avgIntervalMs: 0.0,
        jitterMs: 0.0,
        minIntervalMs: 0.0,
        maxIntervalMs: 0.0,
        gapCount: 0,
        screenOnRateHz: 0.0,
        screenOffRateHz: 0.0,
      );
    }

    final intervalsMs = <double>[];
    for (var i = 1; i < n; i++) {
      final dtMs = (timestampsNs[i] - timestampsNs[i - 1]) / 1e6;
      if (dtMs > 0) {
        intervalsMs.add(dtMs);
      }
    }

    if (intervalsMs.isEmpty) {
      return SensorTimingAnalysis(
        sampleCount: n,
        durationSeconds: 0.0,
        actualRateHz: 0.0,
        avgIntervalMs: 0.0,
        jitterMs: 0.0,
        minIntervalMs: 0.0,
        maxIntervalMs: 0.0,
        gapCount: 0,
        screenOnRateHz: 0.0,
        screenOffRateHz: 0.0,
      );
    }

    final totalDurationS = (timestampsNs.last - timestampsNs.first) / 1e9;
    final avgIntervalMs =
        intervalsMs.reduce((a, b) => a + b) / intervalsMs.length;

    double jitterMs = 0.0;
    if (intervalsMs.length > 1) {
      final sumSq = intervalsMs.fold<double>(
        0.0,
        (prev, val) => prev + (val - avgIntervalMs) * (val - avgIntervalMs),
      );
      jitterMs = sqrt(sumSq / (intervalsMs.length - 1));
    }

    final actualRateHz = avgIntervalMs > 0 ? 1000.0 / avgIntervalMs : 0.0;
    final minIntervalMs = intervalsMs.reduce(min);
    final maxIntervalMs = intervalsMs.reduce(max);

    final gapThreshold = avgIntervalMs * gapThresholdFactor;
    final gapCount = intervalsMs.where((dt) => dt > gapThreshold).length;

    // Analisis status layar on vs off
    double screenOnRateHz = 0.0;
    double screenOffRateHz = 0.0;

    if (screenStates != null && screenStates.length == n) {
      final onIntervals = <double>[];
      final offIntervals = <double>[];

      for (var i = 1; i < n; i++) {
        final dt = (timestampsNs[i] - timestampsNs[i - 1]) / 1e6;
        if (dt > 0) {
          if (screenStates[i]) {
            onIntervals.add(dt);
          } else {
            offIntervals.add(dt);
          }
        }
      }

      if (onIntervals.isNotEmpty) {
        final avgOn = onIntervals.reduce((a, b) => a + b) / onIntervals.length;
        if (avgOn > 0) screenOnRateHz = 1000.0 / avgOn;
      }

      if (offIntervals.isNotEmpty) {
        final avgOff =
            offIntervals.reduce((a, b) => a + b) / offIntervals.length;
        if (avgOff > 0) screenOffRateHz = 1000.0 / avgOff;
      }
    }

    return SensorTimingAnalysis(
      sampleCount: n,
      durationSeconds: totalDurationS,
      actualRateHz: actualRateHz,
      avgIntervalMs: avgIntervalMs,
      jitterMs: jitterMs,
      minIntervalMs: minIntervalMs,
      maxIntervalMs: maxIntervalMs,
      gapCount: gapCount,
      screenOnRateHz: screenOnRateHz,
      screenOffRateHz: screenOffRateHz,
    );
  }
}
