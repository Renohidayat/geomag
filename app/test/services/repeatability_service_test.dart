import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/repeatability_service.dart';

void main() {
  group('RepeatabilityAnalysisService (Dart vs Python parity)', () {
    const service = RepeatabilityAnalysisService();

    test('Dua profil identik menghasilkan selisih 0, korelasi 1.0, dan konsisten', () {
      final seriesA = [45000.0, 45150.0, 45300.0, 45100.0, 44950.0];
      final seriesB = [45000.0, 45150.0, 45300.0, 45100.0, 44950.0];

      final metrics = service.computeMetrics(
        seriesA: seriesA,
        seriesB: seriesB,
        noiseFloorNt: 500.0,
      );

      expect(metrics.sampleCount, 5);
      expect(metrics.meanAbsoluteDiffNt, closeTo(0.0, 1e-9));
      expect(metrics.meanDiffNt, closeTo(0.0, 1e-9));
      expect(metrics.rmseNt, closeTo(0.0, 1e-9));
      expect(metrics.maxAbsoluteDiffNt, closeTo(0.0, 1e-9));
      expect(metrics.pearsonR, closeTo(1.0, 1e-9));
      expect(metrics.toleranceLimitNt, 1000.0); // 2.0 * 500.0
      expect(metrics.withinToleranceRatio, 1.0);
      expect(metrics.isConsistent, isTrue);
      expect(metrics.pairedDifferences, [0.0, 0.0, 0.0, 0.0, 0.0]);
    });

    test('Offset sistematik mempertahankan korelasi 1.0 dan menghitung bias persis', () {
      final baseSignal = [45000.0, 45250.0, 45500.0, 45150.0, 44800.0];
      const offsetNt = 120.0;
      final seriesB = baseSignal.map((v) => v - offsetNt).toList();

      final metrics = service.computeMetrics(
        seriesA: baseSignal,
        seriesB: seriesB,
        noiseFloorNt: 100.0,
        toleranceMultiplier: 2.0,
      );

      expect(metrics.sampleCount, 5);
      expect(metrics.meanAbsoluteDiffNt, closeTo(120.0, 1e-9));
      expect(metrics.meanDiffNt, closeTo(120.0, 1e-9));
      expect(metrics.rmseNt, closeTo(120.0, 1e-9));
      expect(metrics.maxAbsoluteDiffNt, closeTo(120.0, 1e-9));
      expect(metrics.pearsonR, closeTo(1.0, 1e-9));
      expect(metrics.toleranceLimitNt, 200.0);
      expect(metrics.withinToleranceRatio, 1.0);
      expect(metrics.isConsistent, isTrue);
    });

    test('Profil dengan deviasi acak dalam batas toleransi dinyatakan konsisten', () {
      final seriesA = [
        45050.0, 45200.0, 46100.0, 47300.0, 46200.0, 45300.0, 45080.0
      ];
      // Tambahkan deviasi kecil (~50-100 nT)
      final seriesB = [
        45020.0, 45260.0, 46040.0, 47380.0, 46150.0, 45240.0, 45110.0
      ];

      final metrics = service.computeMetrics(
        seriesA: seriesA,
        seriesB: seriesB,
        noiseFloorNt: 300.0, // Batas toleransi = 600.0 nT
      );

      expect(metrics.sampleCount, 7);
      expect(metrics.toleranceLimitNt, 600.0);
      expect(metrics.rmseNt, lessThan(100.0));
      expect(metrics.withinToleranceRatio, 1.0);
      expect(metrics.pearsonR, greaterThan(0.95));
      expect(metrics.isConsistent, isTrue);

      final summary = metrics.toSummaryText();
      expect(summary, contains('KONSISTEN (LULUS)'));
      expect(summary, contains('100.0%'));
    });

    test('Profil tidak konsisten jika RMSE atau persentase toleransi gagal', () {
      final seriesA = [45000.0, 46000.0, 47000.0, 46000.0, 45000.0];
      final seriesB = [45000.0, 44000.0, 43000.0, 44000.0, 45000.0];

      final metrics = service.computeMetrics(
        seriesA: seriesA,
        seriesB: seriesB,
        noiseFloorNt: 300.0, // batas = 600 nT
      );

      expect(metrics.toleranceLimitNt, 600.0);
      expect(metrics.rmseNt, greaterThan(1000.0));
      expect(metrics.withinToleranceRatio, lessThan(0.50));
      expect(metrics.isConsistent, isFalse);

      final summary = metrics.toSummaryText();
      expect(summary, contains('TIDAK KONSISTEN (GAGAL)'));
    });

    test('Validasi edge cases: panjang beda, kosong, atau 1 titik', () {
      expect(
        () => service.computeMetrics(seriesA: [45000.0], seriesB: [45000.0, 45100.0]),
        throwsArgumentError,
      );

      expect(
        () => service.computeMetrics(seriesA: [], seriesB: []),
        throwsArgumentError,
      );

      final singlePoint = service.computeMetrics(
        seriesA: [45000.0],
        seriesB: [45040.0],
        noiseFloorNt: 50.0,
      );
      expect(singlePoint.sampleCount, 1);
      expect(singlePoint.meanAbsoluteDiffNt, 40.0);
      expect(singlePoint.rmseNt, 40.0);
      expect(singlePoint.withinToleranceRatio, 1.0);
    });
  });
}
