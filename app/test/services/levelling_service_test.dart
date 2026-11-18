import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/levelling_service.dart';

void main() {
  const service = LevellingService();

  group('Crossover Point Detection', () {
    test('detects intersection coordinates and interpolates fields accurately', () {
      final sLine = SurveyLine(
        lineId: 'L1',
        lineType: 'survey',
        points: const [
          SurveyLinePoint(x: 10.0, y: 0.0, readingNt: 45000.0),
          SurveyLinePoint(x: 10.0, y: 50.0, readingNt: 45050.0),
        ],
      );
      final tLine = SurveyLine(
        lineId: 'T1',
        lineType: 'tie',
        points: const [
          SurveyLinePoint(x: 0.0, y: 25.0, readingNt: 45020.0),
          SurveyLinePoint(x: 30.0, y: 25.0, readingNt: 45030.0),
        ],
      );

      final crossovers = service.calculateCrossovers([sLine, tLine]);
      expect(crossovers.length, 1);

      final c = crossovers.first;
      expect(c.x, closeTo(10.0, 1e-4));
      expect(c.y, closeTo(25.0, 1e-4));
      expect(c.bSurveyNt, closeTo(45025.0, 1e-4));
      expect(c.bTieNt, closeTo(45023.3333, 1e-4));
      expect(c.errorNt, closeTo(45025.0 - 45023.3333, 1e-4));
    });

    test('returns empty when lines are parallel', () {
      final l1 = SurveyLine(
        lineId: 'L1',
        lineType: 'survey',
        points: const [
          SurveyLinePoint(x: 0.0, y: 0.0, readingNt: 45000.0),
          SurveyLinePoint(x: 0.0, y: 10.0, readingNt: 45010.0),
        ],
      );
      final l2 = SurveyLine(
        lineId: 'L2',
        lineType: 'tie',
        points: const [
          SurveyLinePoint(x: 10.0, y: 0.0, readingNt: 45000.0),
          SurveyLinePoint(x: 10.0, y: 10.0, readingNt: 45010.0),
        ],
      );

      final crossovers = service.calculateCrossovers([l1, l2]);
      expect(crossovers, isEmpty);
    });
  });

  group('Least Squares Levelling Optimization (Dart vs Python)', () {
    test('minimizes crossover errors on synthetic 3x2 grid with known shifts', () {
      double bTrue(double x, double y) => 45000.0 + 2.0 * x - 1.5 * y;

      const shiftS1 = 20.0;
      const shiftS2 = -15.0;
      const shiftS3 = 30.0;
      const shiftT1 = 5.0;
      const shiftT2 = -10.0;

      final lines = [
        SurveyLine(
          lineId: 'L1',
          lineType: 'survey',
          points: [
            SurveyLinePoint(x: 10.0, y: 0.0, readingNt: bTrue(10.0, 0.0) + shiftS1),
            SurveyLinePoint(x: 10.0, y: 50.0, readingNt: bTrue(10.0, 50.0) + shiftS1),
          ],
        ),
        SurveyLine(
          lineId: 'L2',
          lineType: 'survey',
          points: [
            SurveyLinePoint(x: 20.0, y: 0.0, readingNt: bTrue(20.0, 0.0) + shiftS2),
            SurveyLinePoint(x: 20.0, y: 50.0, readingNt: bTrue(20.0, 50.0) + shiftS2),
          ],
        ),
        SurveyLine(
          lineId: 'L3',
          lineType: 'survey',
          points: [
            SurveyLinePoint(x: 30.0, y: 0.0, readingNt: bTrue(30.0, 0.0) + shiftS3),
            SurveyLinePoint(x: 30.0, y: 50.0, readingNt: bTrue(30.0, 50.0) + shiftS3),
          ],
        ),
        SurveyLine(
          lineId: 'T1',
          lineType: 'tie',
          points: [
            SurveyLinePoint(x: 0.0, y: 15.0, readingNt: bTrue(0.0, 15.0) + shiftT1),
            SurveyLinePoint(x: 40.0, y: 15.0, readingNt: bTrue(40.0, 15.0) + shiftT1),
          ],
        ),
        SurveyLine(
          lineId: 'T2',
          lineType: 'tie',
          points: [
            SurveyLinePoint(x: 0.0, y: 35.0, readingNt: bTrue(0.0, 35.0) + shiftT2),
            SurveyLinePoint(x: 40.0, y: 35.0, readingNt: bTrue(40.0, 35.0) + shiftT2),
          ],
        ),
      ];

      final res = service.performLevelling(lines);
      expect(res.isSuccessful, isTrue);
      expect(res.crossoverCount, 6);

      // RMSE sebelum levelling signifikan (> 20 nT)
      expect(res.rmseBeforeNt, greaterThan(20.0));

      // RMSE setelah levelling turun mendekati 0 (< 0.01 nT)
      expect(res.rmseAfterNt, lessThan(0.01));

      // Seluruh residual crossover setelah koreksi < 0.01 nT
      for (final c in res.crossovers) {
        expect(c.residualNt!.abs(), lessThan(0.01));
      }

      // Pastikan levelledLines memiliki pergeseran koreksi
      expect(res.levelledLines.length, 5);
      final l1Levelled = res.levelledLines.firstWhere((l) => l.lineId == 'L1');
      expect(l1Levelled.points.first.readingNt, isNot(equals(bTrue(10.0, 0.0) + shiftS1)));
    });

    test('handles empty crossovers gracefully without crash', () {
      final lines = [
        const SurveyLine(
          lineId: 'L1',
          lineType: 'survey',
          points: [
            SurveyLinePoint(x: 0.0, y: 0.0, readingNt: 45000.0),
            SurveyLinePoint(x: 0.0, y: 10.0, readingNt: 45010.0),
          ],
        ),
      ];

      final res = service.performLevelling(lines);
      expect(res.isSuccessful, isFalse);
      expect(res.crossoverCount, 0);
      expect(res.rmseBeforeNt, 0.0);
      expect(res.rmseAfterNt, 0.0);
    });
  });
}
