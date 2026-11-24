import 'dart:math';

import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/services/calibration/ellipsoid_calibration_service.dart';

/// Hasil perhitungan agregasi stasiun.
class StationAggregationResult {
  final int sampleCount;
  final double meanTotalFieldNt;
  final double stdDevTotalFieldNt;
  final double medianTotalFieldNt;
  final List<double> rawMeanMicroT;
  final List<double>? calibratedMeanMicroT;
  final String qualityFlag; // 'ACCEPTED', 'REJECTED', 'FLAGGED'
  final String statusReason;

  const StationAggregationResult({
    required this.sampleCount,
    required this.meanTotalFieldNt,
    required this.stdDevTotalFieldNt,
    required this.medianTotalFieldNt,
    required this.rawMeanMicroT,
    this.calibratedMeanMicroT,
    required this.qualityFlag,
    required this.statusReason,
  });

  bool get isAccepted => qualityFlag == 'ACCEPTED';
}

/// Service fungsi murni untuk menghitung statistik stasiun survei dan evaluasi mutu.
class StationAggregationService {
  final double maxStdDevNt;
  final int minSamples;

  const StationAggregationService({
    this.maxStdDevNt = 1000.0,
    this.minSamples = 100,
  });

  /// Menghitung agregasi statistik stasiun dari kumpulan sampel magnetometer.
  StationAggregationResult aggregateStationSamples({
    required List<MagnetometerSample> samples,
    EllipsoidCalibrationResult? calibrationProfile,
    double? customMaxStdDevNt,
    int? customMinSamples,
  }) {
    final thresholdMaxStdDev = customMaxStdDevNt ?? maxStdDevNt;
    final thresholdMinSamples = customMinSamples ?? minSamples;

    final n = samples.length;
    if (n == 0) {
      return const StationAggregationResult(
        sampleCount: 0,
        meanTotalFieldNt: 0.0,
        stdDevTotalFieldNt: 0.0,
        medianTotalFieldNt: 0.0,
        rawMeanMicroT: [0.0, 0.0, 0.0],
        qualityFlag: 'REJECTED',
        statusReason: 'Tidak ada sampel yang direkam',
      );
    }

    var sumX = 0.0;
    var sumY = 0.0;
    var sumZ = 0.0;
    final totalFieldList = <double>[];

    var sumCalX = 0.0;
    var sumCalY = 0.0;
    var sumCalZ = 0.0;

    for (final s in samples) {
      sumX += s.rawXMicroT;
      sumY += s.rawYMicroT;
      sumZ += s.rawZMicroT;

      if (calibrationProfile != null) {
        final cal = calibrationProfile.applyCorrection(
          s.rawXMicroT,
          s.rawYMicroT,
          s.rawZMicroT,
        );
        sumCalX += cal[0];
        sumCalY += cal[1];
        sumCalZ += cal[2];

        final magNt = sqrt(cal[0] * cal[0] + cal[1] * cal[1] + cal[2] * cal[2]) * 1000.0;
        totalFieldList.add(magNt);
      } else {
        totalFieldList.add(s.calibratedTotalFieldNt);
      }
    }

    final meanX = sumX / n;
    final meanY = sumY / n;
    final meanZ = sumZ / n;

    final meanTotal = totalFieldList.reduce((a, b) => a + b) / n;

    // Simpangan baku
    var sumSqDiff = 0.0;
    for (final val in totalFieldList) {
      final diff = val - meanTotal;
      sumSqDiff += diff * diff;
    }
    final stdDev = n > 1 ? sqrt(sumSqDiff / (n - 1)) : 0.0;

    // Median
    final sorted = List<double>.from(totalFieldList)..sort();
    final median = n % 2 == 1
        ? sorted[n ~/ 2]
        : 0.5 * (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]);

    List<double>? calMean;
    if (calibrationProfile != null) {
      calMean = [sumCalX / n, sumCalY / n, sumCalZ / n];
    }

    // Evaluasi mutu dan protokol penolakan
    String flag;
    String reason;

    if (n < thresholdMinSamples) {
      flag = 'REJECTED';
      reason = 'Jumlah sampel ($n) kurang dari batas minimum ($thresholdMinSamples)';
    } else if (stdDev > thresholdMaxStdDev) {
      flag = 'REJECTED';
      reason = 'Simpangan baku (${stdDev.toStringAsFixed(1)} nT) melampaui batas toleransi (${thresholdMaxStdDev.toStringAsFixed(1)} nT)';
    } else if (stdDev > thresholdMaxStdDev * 0.75) {
      flag = 'FLAGGED';
      reason = 'Simpangan baku (${stdDev.toStringAsFixed(1)} nT) mendekati ambang toleransi';
    } else {
      flag = 'ACCEPTED';
      reason = 'Kualitas stasiun baik dan stabil';
    }

    return StationAggregationResult(
      sampleCount: n,
      meanTotalFieldNt: meanTotal,
      stdDevTotalFieldNt: stdDev,
      medianTotalFieldNt: median,
      rawMeanMicroT: [meanX, meanY, meanZ],
      calibratedMeanMicroT: calMean,
      qualityFlag: flag,
      statusReason: reason,
    );
  }
}
