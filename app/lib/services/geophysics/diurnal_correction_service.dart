// Status evaluasi koreksi variasi harian.
enum DiurnalCorrectionStatus {
  /// Berhasil diinterpolasi dan dikoreksi.
  success,

  /// Waktu rover mendahului rekaman base station di luar toleransi batas.
  outOfRangeEarly,

  /// Waktu rover melampaui akhir rekaman base station di luar toleransi batas.
  outOfRangeLate,

  /// Gap waktu antar dua titik base station terdekat terlalu besar (> maxAllowedGap).
  gapTooLarge,

  /// Data rekaman base station kosong.
  noBaseData,

  /// Data rekaman base station tidak mencukupi (misal hanya 1 titik dan di luar toleransi).
  insufficientBaseData,
}

/// Titik data pembacaan base station untuk koreksi variasi harian.
class BaseReadingPoint {
  /// Waktu dalam epoch milidetik (UTC/lokal tersinkron).
  final int timestampMs;

  /// Medan total hasil pembacaan base station (nT).
  final double totalFieldNt;

  const BaseReadingPoint({
    required this.timestampMs,
    required this.totalFieldNt,
  });

  /// Factory dari DateTime.
  BaseReadingPoint.fromDateTime({
    required DateTime time,
    required double totalFieldNt,
  }) : this(
          timestampMs: time.millisecondsSinceEpoch,
          totalFieldNt: totalFieldNt,
        );

  /// Factory dari epoch detik (misal dari referensi Python).
  BaseReadingPoint.fromSeconds({
    required double timestampSeconds,
    required double totalFieldNt,
  }) : this(
          timestampMs: (timestampSeconds * 1000).round(),
          totalFieldNt: totalFieldNt,
        );
}

/// Rekaman stasiun rover yang akan dikoreksi.
class RoverStationRecord {
  final String stationId;
  final int timestampMs;
  final double totalFieldNt;

  const RoverStationRecord({
    required this.stationId,
    required this.timestampMs,
    required this.totalFieldNt,
  });

  RoverStationRecord.fromDateTime({
    required this.stationId,
    required DateTime time,
    required this.totalFieldNt,
  }) : timestampMs = time.millisecondsSinceEpoch;
}

/// Hasil perhitungan koreksi variasi harian.
class DiurnalCorrectionResult {
  final bool isValid;
  final int roverTimestampMs;
  final double roverFieldNt;
  final double? baseInterpolatedNt;
  final double? diurnalCorrectionNt;
  final double? correctedFieldNt;
  final double? baselineB0Nt;
  final DiurnalCorrectionStatus status;
  final String? errorMessage;

  const DiurnalCorrectionResult({
    required this.isValid,
    required this.roverTimestampMs,
    required this.roverFieldNt,
    this.baseInterpolatedNt,
    this.diurnalCorrectionNt,
    this.correctedFieldNt,
    this.baselineB0Nt,
    required this.status,
    this.errorMessage,
  });
}

/// Service fungsi murni untuk menghitung koreksi variasi harian (diurnal correction).
///
/// Rumus geofisika:
///   Delta B_diurnal(t) = B_base(t) - B0
///   B_corrected(t)     = B_rover(t) - Delta B_diurnal(t)
///                      = B_rover(t) - (B_base(t) - B0)
class DiurnalCorrectionService {
  /// Gap waktu maksimum yang diizinkan antar dua titik base station (detik).
  final double defaultMaxAllowedGapS;

  /// Toleransi waktu di luar batas awal/akhir base station yang masih ditoleransi via clamping (detik).
  final double defaultBoundaryToleranceS;

  const DiurnalCorrectionService({
    this.defaultMaxAllowedGapS = 600.0,
    this.defaultBoundaryToleranceS = 30.0,
  });

  /// Menghitung baseline B0 dari kumpulan titik base station (menggunakan median).
  double calculateBaselineB0(List<BaseReadingPoint> basePoints) {
    if (basePoints.isEmpty) {
      throw ArgumentError('Kumpulan titik base station tidak boleh kosong untuk menghitung B0');
    }
    final sortedValues = basePoints.map((p) => p.totalFieldNt).toList()..sort();
    final n = sortedValues.length;
    if (n.isOdd) {
      return sortedValues[n ~/ 2];
    } else {
      return (sortedValues[n ~/ 2 - 1] + sortedValues[n ~/ 2]) / 2.0;
    }
  }

  /// Melakukan interpolasi linier nilai base station pada waktu roverTimestampMs.
  ///
  /// Menggunakan binary search O(log N).
  ({
    double? interpolatedFieldNt,
    DiurnalCorrectionStatus status,
    String? errorMessage,
  }) interpolateBaseReading({
    required List<BaseReadingPoint> sortedBasePoints,
    required int roverTimestampMs,
    double? maxAllowedGapS,
    double? boundaryToleranceS,
  }) {
    final maxGapMs = ((maxAllowedGapS ?? defaultMaxAllowedGapS) * 1000).round();
    final toleranceMs =
        ((boundaryToleranceS ?? defaultBoundaryToleranceS) * 1000).round();

    final n = sortedBasePoints.length;
    if (n == 0) {
      return (
        interpolatedFieldNt: null,
        status: DiurnalCorrectionStatus.noBaseData,
        errorMessage: 'Data base station kosong',
      );
    }

    if (n == 1) {
      final diff = (roverTimestampMs - sortedBasePoints[0].timestampMs).abs();
      if (diff <= toleranceMs) {
        return (
          interpolatedFieldNt: sortedBasePoints[0].totalFieldNt,
          status: DiurnalCorrectionStatus.success,
          errorMessage: null,
        );
      }
      return (
        interpolatedFieldNt: null,
        status: DiurnalCorrectionStatus.insufficientBaseData,
        errorMessage:
            'Data base station hanya memiliki 1 sampel dan rover berada di luar batas toleransi',
      );
    }

    final tStart = sortedBasePoints.first.timestampMs;
    final tEnd = sortedBasePoints.last.timestampMs;

    // Sebelum titik awal
    if (roverTimestampMs < tStart) {
      if ((tStart - roverTimestampMs) <= toleranceMs) {
        return (
          interpolatedFieldNt: sortedBasePoints.first.totalFieldNt,
          status: DiurnalCorrectionStatus.success,
          errorMessage: null,
        );
      }
      return (
        interpolatedFieldNt: null,
        status: DiurnalCorrectionStatus.outOfRangeEarly,
        errorMessage:
            'Waktu rover sebelum rekaman base melebihi batas toleransi (${toleranceMs / 1000}s)',
      );
    }

    // Setelah titik akhir
    if (roverTimestampMs > tEnd) {
      if ((roverTimestampMs - tEnd) <= toleranceMs) {
        return (
          interpolatedFieldNt: sortedBasePoints.last.totalFieldNt,
          status: DiurnalCorrectionStatus.success,
          errorMessage: null,
        );
      }
      return (
        interpolatedFieldNt: null,
        status: DiurnalCorrectionStatus.outOfRangeLate,
        errorMessage:
            'Waktu rover setelah rekaman base melebihi batas toleransi (${toleranceMs / 1000}s)',
      );
    }

    // Binary search untuk interval [idx - 1, idx]
    int low = 0;
    int high = n - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (sortedBasePoints[mid].timestampMs < roverTimestampMs) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    final idx = low;
    if (idx == 0) {
      return (
        interpolatedFieldNt: sortedBasePoints[0].totalFieldNt,
        status: DiurnalCorrectionStatus.success,
        errorMessage: null,
      );
    }
    if (idx >= n) {
      return (
        interpolatedFieldNt: sortedBasePoints[n - 1].totalFieldNt,
        status: DiurnalCorrectionStatus.success,
        errorMessage: null,
      );
    }

    final p1 = sortedBasePoints[idx - 1];
    final p2 = sortedBasePoints[idx];

    final dt = p2.timestampMs - p1.timestampMs;
    if (dt < 0) {
      throw StateError('Data base station harus terurut menaik secara waktu');
    }

    if (dt > maxGapMs) {
      return (
        interpolatedFieldNt: null,
        status: DiurnalCorrectionStatus.gapTooLarge,
        errorMessage:
            'Gap waktu base station (${dt / 1000}s) melebihi batas maksimum (${maxGapMs / 1000}s)',
      );
    }

    if (dt == 0) {
      return (
        interpolatedFieldNt: p1.totalFieldNt,
        status: DiurnalCorrectionStatus.success,
        errorMessage: null,
      );
    }

    final alpha = (roverTimestampMs - p1.timestampMs) / dt;
    final bInterp = p1.totalFieldNt + alpha * (p2.totalFieldNt - p1.totalFieldNt);

    return (
      interpolatedFieldNt: bInterp,
      status: DiurnalCorrectionStatus.success,
      errorMessage: null,
    );
  }

  /// Menghitung koreksi variasi harian untuk satu stasiun rover.
  DiurnalCorrectionResult computeDiurnalCorrection({
    required List<BaseReadingPoint> basePoints,
    required int roverTimestampMs,
    required double roverFieldNt,
    double? baselineB0Nt,
    double? maxAllowedGapS,
    double? boundaryToleranceS,
  }) {
    if (basePoints.isEmpty) {
      return DiurnalCorrectionResult(
        isValid: false,
        roverTimestampMs: roverTimestampMs,
        roverFieldNt: roverFieldNt,
        status: DiurnalCorrectionStatus.noBaseData,
        errorMessage: 'Data base station kosong',
      );
    }

    // Pastikan terurut berdasarkan waktu
    final sortedBase = List<BaseReadingPoint>.from(basePoints)
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    final b0 = baselineB0Nt ?? calculateBaselineB0(sortedBase);

    final interpRes = interpolateBaseReading(
      sortedBasePoints: sortedBase,
      roverTimestampMs: roverTimestampMs,
      maxAllowedGapS: maxAllowedGapS,
      boundaryToleranceS: boundaryToleranceS,
    );

    if (interpRes.status != DiurnalCorrectionStatus.success ||
        interpRes.interpolatedFieldNt == null) {
      return DiurnalCorrectionResult(
        isValid: false,
        roverTimestampMs: roverTimestampMs,
        roverFieldNt: roverFieldNt,
        baselineB0Nt: b0,
        status: interpRes.status,
        errorMessage: interpRes.errorMessage,
      );
    }

    final bInterp = interpRes.interpolatedFieldNt!;
    final diurnalCorr = bInterp - b0;
    final bCorrected = roverFieldNt - diurnalCorr;

    return DiurnalCorrectionResult(
      isValid: true,
      roverTimestampMs: roverTimestampMs,
      roverFieldNt: roverFieldNt,
      baseInterpolatedNt: bInterp,
      diurnalCorrectionNt: diurnalCorr,
      correctedFieldNt: bCorrected,
      baselineB0Nt: b0,
      status: DiurnalCorrectionStatus.success,
      errorMessage: null,
    );
  }

  /// Menghitung koreksi variasi harian untuk sekumpulan titik stasiun survei rover (batch).
  List<({String stationId, DiurnalCorrectionResult result})> correctRoverSurvey({
    required List<BaseReadingPoint> basePoints,
    required List<RoverStationRecord> roverRecords,
    double? baselineB0Nt,
    double? maxAllowedGapS,
    double? boundaryToleranceS,
  }) {
    if (basePoints.isEmpty) {
      return roverRecords
          .map((rec) => (
                stationId: rec.stationId,
                result: computeDiurnalCorrection(
                  basePoints: basePoints,
                  roverTimestampMs: rec.timestampMs,
                  roverFieldNt: rec.totalFieldNt,
                  baselineB0Nt: baselineB0Nt,
                  maxAllowedGapS: maxAllowedGapS,
                  boundaryToleranceS: boundaryToleranceS,
                )
              ))
          .toList();
    }

    final sortedBase = List<BaseReadingPoint>.from(basePoints)
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    final b0 = baselineB0Nt ?? calculateBaselineB0(sortedBase);

    return roverRecords.map((rec) {
      final res = computeDiurnalCorrection(
        basePoints: sortedBase,
        roverTimestampMs: rec.timestampMs,
        roverFieldNt: rec.totalFieldNt,
        baselineB0Nt: b0,
        maxAllowedGapS: maxAllowedGapS,
        boundaryToleranceS: boundaryToleranceS,
      );
      return (stationId: rec.stationId, result: res);
    }).toList();
  }
}
