import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/diurnal_correction_service.dart';

void main() {
  late DiurnalCorrectionService service;

  setUp(() {
    service = const DiurnalCorrectionService(
      defaultMaxAllowedGapS: 600.0,
      defaultBoundaryToleranceS: 30.0,
    );
  });

  group('Linear Interpolation Base Reading', () {
    test('linear interpolation exact midpoint and fraction match Python reference', () {
      final basePoints = [
        BaseReadingPoint.fromSeconds(timestampSeconds: 0.0, totalFieldNt: 45000.0),
        BaseReadingPoint.fromSeconds(timestampSeconds: 100.0, totalFieldNt: 45050.0),
        BaseReadingPoint.fromSeconds(timestampSeconds: 200.0, totalFieldNt: 45020.0),
      ];

      // Exact midpoint t=50s -> 45025.0
      final resMid = service.interpolateBaseReading(
        sortedBasePoints: basePoints,
        roverTimestampMs: 50 * 1000,
      );
      expect(resMid.status, DiurnalCorrectionStatus.success);
      expect(resMid.interpolatedFieldNt, closeTo(45025.0, 1e-4));

      // At t=150s -> 45050 + 0.5 * (45020 - 45050) = 45035.0
      final res150 = service.interpolateBaseReading(
        sortedBasePoints: basePoints,
        roverTimestampMs: 150 * 1000,
      );
      expect(res150.status, DiurnalCorrectionStatus.success);
      expect(res150.interpolatedFieldNt, closeTo(45035.0, 1e-4));

      // Exactly at existing sample t=100s -> 45050.0
      final res100 = service.interpolateBaseReading(
        sortedBasePoints: basePoints,
        roverTimestampMs: 100 * 1000,
      );
      expect(res100.status, DiurnalCorrectionStatus.success);
      expect(res100.interpolatedFieldNt, closeTo(45050.0, 1e-4));
    });
  });

  group('Diurnal Correction Formula', () {
    test('computes diurnal correction and corrected field correctly (Dart vs Python match)', () {
      final basePoints = [
        BaseReadingPoint.fromSeconds(timestampSeconds: 1000.0, totalFieldNt: 45000.0),
        BaseReadingPoint.fromSeconds(timestampSeconds: 1100.0, totalFieldNt: 45020.0),
        BaseReadingPoint.fromSeconds(timestampSeconds: 1200.0, totalFieldNt: 45040.0),
      ];

      // At t=1050s:
      // B_base_interp = 45010.0
      // B0 = 45000.0
      // Delta B_diurnal = 45010 - 45000 = +10.0 nT
      // Rover field = 45350.0 nT
      // Corrected = 45350 - 10 = 45340.0 nT
      final res = service.computeDiurnalCorrection(
        basePoints: basePoints,
        roverTimestampMs: 1050 * 1000,
        roverFieldNt: 45350.0,
        baselineB0Nt: 45000.0,
      );

      expect(res.isValid, isTrue);
      expect(res.status, DiurnalCorrectionStatus.success);
      expect(res.baseInterpolatedNt, closeTo(45010.0, 1e-4));
      expect(res.diurnalCorrectionNt, closeTo(10.0, 1e-4));
      expect(res.correctedFieldNt, closeTo(45340.0, 1e-4));
      expect(res.baselineB0Nt, closeTo(45000.0, 1e-4));
    });

    test('calculates median baseline B0 automatically when not provided', () {
      final basePoints = [
        BaseReadingPoint.fromSeconds(timestampSeconds: 100.0, totalFieldNt: 45000.0),
        BaseReadingPoint.fromSeconds(timestampSeconds: 200.0, totalFieldNt: 45020.0),
        BaseReadingPoint.fromSeconds(timestampSeconds: 300.0, totalFieldNt: 45040.0),
      ];

      final b0 = service.calculateBaselineB0(basePoints);
      expect(b0, closeTo(45020.0, 1e-4));

      final res = service.computeDiurnalCorrection(
        basePoints: basePoints,
        roverTimestampMs: 100 * 1000,
        roverFieldNt: 45100.0,
      );
      // t=100 -> b_base=45000, b0=45020 -> diurnal = -20 nT
      // b_corr = 45100 - (-20) = 45120 nT
      expect(res.isValid, isTrue);
      expect(res.baselineB0Nt, closeTo(45020.0, 1e-4));
      expect(res.diurnalCorrectionNt, closeTo(-20.0, 1e-4));
      expect(res.correctedFieldNt, closeTo(45120.0, 1e-4));
    });
  });

  group('Boundary Tolerances and Range Checking', () {
    final basePoints = [
      BaseReadingPoint.fromSeconds(timestampSeconds: 100.0, totalFieldNt: 45000.0),
      BaseReadingPoint.fromSeconds(timestampSeconds: 200.0, totalFieldNt: 45050.0),
    ];

    test('clamps to start within boundary tolerance (t=90s with 30s tolerance)', () {
      final res = service.computeDiurnalCorrection(
        basePoints: basePoints,
        roverTimestampMs: 90 * 1000,
        roverFieldNt: 45200.0,
        baselineB0Nt: 45000.0,
        boundaryToleranceS: 30.0,
      );
      expect(res.isValid, isTrue);
      expect(res.baseInterpolatedNt, closeTo(45000.0, 1e-4));
      expect(res.correctedFieldNt, closeTo(45200.0, 1e-4));
    });

    test('rejects early timestamp outside tolerance (t=50s with 30s tolerance)', () {
      final res = service.computeDiurnalCorrection(
        basePoints: basePoints,
        roverTimestampMs: 50 * 1000,
        roverFieldNt: 45200.0,
        baselineB0Nt: 45000.0,
        boundaryToleranceS: 30.0,
      );
      expect(res.isValid, isFalse);
      expect(res.status, DiurnalCorrectionStatus.outOfRangeEarly);
      expect(res.correctedFieldNt, isNull);
    });

    test('clamps to end within boundary tolerance (t=215s with 30s tolerance)', () {
      final res = service.computeDiurnalCorrection(
        basePoints: basePoints,
        roverTimestampMs: 215 * 1000,
        roverFieldNt: 45200.0,
        baselineB0Nt: 45000.0,
        boundaryToleranceS: 30.0,
      );
      expect(res.isValid, isTrue);
      expect(res.baseInterpolatedNt, closeTo(45050.0, 1e-4));
      expect(res.correctedFieldNt, closeTo(45150.0, 1e-4));
    });

    test('rejects late timestamp outside tolerance (t=260s with 30s tolerance)', () {
      final res = service.computeDiurnalCorrection(
        basePoints: basePoints,
        roverTimestampMs: 260 * 1000,
        roverFieldNt: 45200.0,
        baselineB0Nt: 45000.0,
        boundaryToleranceS: 30.0,
      );
      expect(res.isValid, isFalse);
      expect(res.status, DiurnalCorrectionStatus.outOfRangeLate);
      expect(res.correctedFieldNt, isNull);
    });
  });

  group('Gap and Edge Cases', () {
    test('rejects interpolation when gap between base points exceeds maxAllowedGap', () {
      final basePoints = [
        BaseReadingPoint.fromSeconds(timestampSeconds: 0.0, totalFieldNt: 45000.0),
        BaseReadingPoint.fromSeconds(timestampSeconds: 1500.0, totalFieldNt: 45030.0),
      ];

      final res = service.computeDiurnalCorrection(
        basePoints: basePoints,
        roverTimestampMs: 500 * 1000,
        roverFieldNt: 45100.0,
        maxAllowedGapS: 600.0,
      );

      expect(res.isValid, isFalse);
      expect(res.status, DiurnalCorrectionStatus.gapTooLarge);
      expect(res.errorMessage, contains('Gap waktu'));
    });

    test('returns noBaseData when base points list is empty', () {
      final res = service.computeDiurnalCorrection(
        basePoints: [],
        roverTimestampMs: 100 * 1000,
        roverFieldNt: 45100.0,
      );

      expect(res.isValid, isFalse);
      expect(res.status, DiurnalCorrectionStatus.noBaseData);
    });
  });

  group('Batch Rover Survey Correction', () {
    test('corrects batch of rover records matching Python results', () {
      final basePoints = [
        BaseReadingPoint.fromSeconds(timestampSeconds: 100.0, totalFieldNt: 45000.0),
        BaseReadingPoint.fromSeconds(timestampSeconds: 200.0, totalFieldNt: 45020.0),
        BaseReadingPoint.fromSeconds(timestampSeconds: 300.0, totalFieldNt: 45040.0),
      ];

      final roverRecords = [
        const RoverStationRecord(stationId: 'ST-01', timestampMs: 100000, totalFieldNt: 45100.0),
        const RoverStationRecord(stationId: 'ST-02', timestampMs: 150000, totalFieldNt: 45150.0),
        const RoverStationRecord(stationId: 'ST-03', timestampMs: 250000, totalFieldNt: 45200.0),
        const RoverStationRecord(stationId: 'ST-04', timestampMs: 500000, totalFieldNt: 45300.0),
      ];

      final results = service.correctRoverSurvey(
        basePoints: basePoints,
        roverRecords: roverRecords,
      );

      expect(results.length, 4);

      // ST-01
      expect(results[0].stationId, 'ST-01');
      expect(results[0].result.isValid, isTrue);
      expect(results[0].result.baseInterpolatedNt, closeTo(45000.0, 1e-4));
      expect(results[0].result.diurnalCorrectionNt, closeTo(-20.0, 1e-4));
      expect(results[0].result.correctedFieldNt, closeTo(45120.0, 1e-4));

      // ST-02
      expect(results[1].stationId, 'ST-02');
      expect(results[1].result.isValid, isTrue);
      expect(results[1].result.baseInterpolatedNt, closeTo(45010.0, 1e-4));
      expect(results[1].result.diurnalCorrectionNt, closeTo(-10.0, 1e-4));
      expect(results[1].result.correctedFieldNt, closeTo(45160.0, 1e-4));

      // ST-04 (Out of range)
      expect(results[3].stationId, 'ST-04');
      expect(results[3].result.isValid, isFalse);
      expect(results[3].result.status, DiurnalCorrectionStatus.outOfRangeLate);
    });
  });
}
