import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/models/device_thermal_sample.dart';
import 'package:geomag/services/thermal_state_estimator.dart';

void main() {
  group('Paritas Algoritma Fisika Termal Dart vs Python', () {
    test('computeLinearSlope menghasilkan slope persis sama dengan referensi Python', () {
      final times = [0.0, 10.0, 20.0, 30.0];
      final values = [20.0, 25.0, 30.0, 35.0];
      final slope = computeLinearSlope(times, values);
      expect(slope, closeTo(0.5, 1e-9));

      final flatTimes = [0.0, 5.0, 10.0, 15.0];
      final flatValues = [27.0, 27.0, 27.0, 27.0];
      final flatSlope = computeLinearSlope(flatTimes, flatValues);
      expect(flatSlope, closeTo(0.0, 1e-9));
    });

    test('fitThermalParameters membaca CSV fixture dan cocok dengan Python (toleransi 1e-6)', () {
      final file = File('test/fixtures/thermal_calibration_fixture.csv');
      expect(file.existsSync(), isTrue, reason: 'Fixture CSV harus ada di test/fixtures/');

      final lines = file.readAsLinesSync();
      // Skip header
      final times = <double>[];
      final bats = <double>[];
      final refs = <double>[];

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        times.add(double.parse(parts[0]));
        bats.add(double.parse(parts[1]));
        refs.add(double.parse(parts[5]));
      }

      expect(times.length, 181);

      final params = fitThermalParameters(
        timesS: times,
        batTemps: bats,
        refTemps: refs,
        windowS: 180.0,
      );

      // Paritas eksak dengan reference/tests/test_room_temp_fit.py
      expect(params['a']!, closeTo(1.0, 1e-6));
      expect(params['d0']!, inInclusiveRange(2.5, 4.0));
      expect(params['b']!, closeTo(-params['d0']!, 1e-6));
      expect(params['tau']!, inInclusiveRange(100.0, 400.0));
      expect(params['rmse']!, lessThan(1.0));
    });

    test('fitSteadyOffset menghitung rata-rata dan deviasi standar', () {
      final bats = [30.0, 30.2, 29.8, 30.0];
      const ref = 26.0;
      final res = fitSteadyOffset(bats, ref);
      expect(res['d0']!, closeTo(4.0, 1e-6));
      expect(res['stdDev']!, lessThan(0.2));
    });
  });

  group('ThermalStateEstimator & Tabel Uji 20 - 45 °C', () {
    late ThermalStateEstimator estimator;

    setUp(() {
      estimator = ThermalStateEstimator();
    });

    test('Tabel 20 s.d. 45 °C: output monoton naik secara ketat, tidak ada angka 27.0 beku', () {
      final results = <double, double>{};
      double? prevEst;

      for (double t = 20.0; t <= 45.0; t += 1.0) {
        estimator.reset();
        // Beri sampel selama 4 menit agar keluar dari state collectingData
        for (int i = 0; i <= 48; i++) {
          final res = estimator.processSample(
            sample: DeviceThermalSample(
              timestampNs: i * 5 * 1000000000,
              batteryTempC: t,
              isCharging: false,
              isScreenOn: true,
              currentNowMa: -150.0,
            ),
          );
          if (i == 48) {
            expect(res.estimatedTempC, isNotNull);
            results[t] = res.estimatedTempC!;
            if (prevEst != null) {
              expect(
                res.estimatedTempC!,
                greaterThan(prevEst),
                reason: 'Suhu estimasi pada $t°C (${res.estimatedTempC}) harus > pada ${t - 1}°C ($prevEst)',
              );
            }
            prevEst = res.estimatedTempC;
          }
        }
      }

      // Verifikasi nilai menyebar luas dan logis
      expect(results[20.0]!, closeTo(17.0, 1.0));
      expect(results[30.0]!, closeTo(27.0, 1.0));
      expect(results[35.0]!, closeTo(32.0, 1.0));
      expect(results[40.0]!, closeTo(37.0, 1.0));
      expect(results[45.0]!, closeTo(42.0, 1.0));
    });

    test('Status collectingData saat jendela data kurang dari 3 menit', () {
      final res = estimator.processSample(
        sample: const DeviceThermalSample(
          timestampNs: 10 * 1000000000, // 10 detik
          batteryTempC: 32.0,
          isCharging: false,
          isScreenOn: true,
        ),
      );

      expect(res.state, ThermalState.collectingData);
      expect(res.statusLabel, contains('Mengumpulkan data...'));
    });

    test('Hardware ambient sensor langsung digunakan jika tersedia', () {
      final res = estimator.processSample(
        sample: const DeviceThermalSample(
          timestampNs: 10 * 1000000000,
          batteryTempC: 36.0,
          isCharging: false,
          isScreenOn: true,
          hasAmbientHardwareSensor: true,
          ambientTempHardwareC: 24.2,
        ),
      );

      expect(res.state, ThermalState.hardwareAmbient);
      expect(res.estimatedTempC, closeTo(24.2, 1e-4));
      expect(res.uncertaintyC, closeTo(0.5, 1e-4));
      expect(res.isHardwareSensor, isTrue);
    });

    test('Charging/heavy load menghasilkan label peringatan akurasi', () {
      // Simulasikan data stabil lalu masuk charging
      for (int i = 0; i <= 40; i++) {
        estimator.processSample(
          sample: DeviceThermalSample(
            timestampNs: i * 5 * 1000000000,
            batteryTempC: 33.0,
            isCharging: false,
            isScreenOn: true,
          ),
        );
      }

      final res = estimator.processSample(
        sample: const DeviceThermalSample(
          timestampNs: 205 * 1000000000,
          batteryTempC: 35.0,
          isCharging: true,
          isScreenOn: true,
        ),
      );

      expect(res.state, ThermalState.chargingOrHeavyLoad);
      expect(res.statusLabel, contains('Kurang akurat'));
      expect(res.uncertaintyC, greaterThanOrEqualTo(3.0));
    });

    test('Sensor tidak tersedia (<= 0) menghasilkan estimasi null', () {
      final res = estimator.processSample(
        sample: const DeviceThermalSample(
          timestampNs: 1000,
          batteryTempC: -1.0,
          isCharging: false,
          isScreenOn: false,
        ),
      );

      expect(res.estimatedTempC, isNull);
      expect(res.statusLabel, 'Sensor tidak tersedia');
    });
  });
}
