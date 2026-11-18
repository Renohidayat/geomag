import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/sensor_diagnostics_service.dart';

void main() {
  group('SensorDiagnosticsService (Dart vs Python reference)', () {
    late SensorDiagnosticsService service;

    setUp(() {
      service = SensorDiagnosticsService();
    });

    test('Laju sampling konstan 50 Hz cocok dengan Python', () {
      const dtNs = 20000000;
      final timestamps = List.generate(101, (i) => 1000000000 + i * dtNs);

      final analysis = service.analyzeTiming(timestampsNs: timestamps);

      expect(analysis.sampleCount, 101);
      expect(analysis.durationSeconds, closeTo(2.0, 1e-6));
      expect(analysis.actualRateHz, closeTo(50.0, 1e-6));
      expect(analysis.avgIntervalMs, closeTo(20.0, 1e-6));
      expect(analysis.jitterMs, closeTo(0.0, 1e-6));
      expect(analysis.gapCount, 0);
    });

    test('Jitter dan gap detection cocok dengan Python', () {
      final timestamps = [
        1000000000,
        1020000000, // +20ms
        1042000000, // +22ms
        1061000000, // +19ms
        1079000000, // +18ms
        1180000000, // +101ms (GAP)
        1200000000, // +20ms
      ];

      final analysis = service.analyzeTiming(timestampsNs: timestamps);

      expect(analysis.sampleCount, 7);
      expect(analysis.gapCount, 1);
      expect(analysis.maxIntervalMs, closeTo(101.0, 1e-6));
      expect(analysis.minIntervalMs, closeTo(18.0, 1e-6));
      expect(analysis.jitterMs, greaterThan(0.0));
    });

    test('Analisis layar hidup vs layar mati cocok dengan Python', () {
      final ts = <int>[1000000000];
      final screen = <bool>[true];

      for (var i = 0; i < 4; i++) {
        ts.add(ts.last + 20000000); // 50 Hz
        screen.add(true);
      }

      for (var i = 0; i < 5; i++) {
        ts.add(ts.last + 50000000); // 20 Hz
        screen.add(false);
      }

      final analysis = service.analyzeTiming(
        timestampsNs: ts,
        screenStates: screen,
      );

      expect(analysis.sampleCount, 10);
      expect(analysis.screenOnRateHz, closeTo(50.0, 1e-2));
      expect(analysis.screenOffRateHz, closeTo(20.0, 1e-2));
    });
  });
}
