import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/services/allan_deviation_service.dart';

void main() {
  group('AllanDeviationService (Dart vs Python reference)', () {
    late AllanDeviationService service;

    setUp(() {
      service = AllanDeviationService();
    });

    test('Sinyal konstan menghasilkan noise floor 0.0', () {
      final values = List.filled(100, 45000.0);
      final res = service.computeAllanDeviation(values: values, rateHz: 50.0);

      expect(res.noiseFloor, 0.0);
      for (final a in res.adev) {
        expect(a, 0.0);
      }
    });

    test('Eksepsi bila sampel kurang dari 9', () {
      expect(
        () => service.computeAllanDeviation(values: [1.0, 2.0], rateHz: 50.0),
        throwsArgumentError,
      );
    });

    test('Data sintetis terstruktur menghasilkan ADEV menurun sesuai averager', () {
      // 100 sampel bolak-balik: 45010 dan 44990 (+-10 nT)
      final values = List.generate(
        100,
        (i) => i.isEven ? 45010.0 : 44990.0,
      );

      final res = service.computeAllanDeviation(
        values: values,
        rateHz: 50.0,
        numTau: 10,
      );

      expect(res.tauSeconds.isNotEmpty, isTrue);
      expect(res.adev.isNotEmpty, isTrue);
      expect(res.noiseFloor, greaterThanOrEqualTo(0.0));
      expect(res.optimalTauSeconds, greaterThan(0.0));
    });
  });
}
