import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/services/ellipsoid_calibration_service.dart';
import 'package:geomag/services/station_aggregation_service.dart';

MagnetometerSample createSample({
  required int index,
  required double x,
  required double y,
  required double z,
}) {
  return MagnetometerSample(
    timestampNs: 1000000000 + index * 20000000,
    rawXMicroT: x,
    rawYMicroT: y,
    rawZMicroT: z,
    biasXMicroT: 0.0,
    biasYMicroT: 0.0,
    biasZMicroT: 0.0,
    accuracy: 3,
    isUncalibrated: true,
    batteryTempC: 30.0,
    isCharging: false,
    isScreenOn: true,
  );
}

void main() {
  group('StationAggregationService', () {
    const service = StationAggregationService(
      maxStdDevNt: 500.0,
      minSamples: 50,
    );

    test('Agregasi normal menghasilkan ACCEPTED dengan statistik valid', () {
      final samples = List.generate(
        100,
        (i) => createSample(
          index: i,
          x: 45.0 + (i % 2 == 0 ? 0.05 : -0.05), // Fluktuasi kecil 50 nT
          y: 0.0,
          z: 0.0,
        ),
      );

      final result = service.aggregateStationSamples(samples: samples);

      expect(result.sampleCount, equals(100));
      expect(result.meanTotalFieldNt, closeTo(45000.0, 10.0));
      expect(result.stdDevTotalFieldNt, lessThan(100.0));
      expect(result.qualityFlag, equals('ACCEPTED'));
      expect(result.isAccepted, isTrue);
      expect(result.rawMeanMicroT[0], closeTo(45.0, 0.05));
    });

    test('Penolakan otomatis jika jumlah sampel kurang dari minSamples', () {
      final samples = List.generate(
        30, // Kurang dari 50
        (i) => createSample(index: i, x: 45.0, y: 0.0, z: 0.0),
      );

      final result = service.aggregateStationSamples(samples: samples);

      expect(result.qualityFlag, equals('REJECTED'));
      expect(result.isAccepted, isFalse);
      expect(result.statusReason, contains('kurang dari batas minimum'));
    });

    test('Penolakan otomatis jika simpangan baku melebihi maxStdDevNt', () {
      final samples = List.generate(
        100,
        (i) => createSample(
          index: i,
          x: 45.0 + (i.isEven ? 1.5 : -1.5), // Noise besar +- 1500 nT
          y: 0.0,
          z: 0.0,
        ),
      );

      final result = service.aggregateStationSamples(samples: samples);

      expect(result.stdDevTotalFieldNt, greaterThan(1000.0));
      expect(result.qualityFlag, equals('REJECTED'));
      expect(result.isAccepted, isFalse);
      expect(result.statusReason, contains('melampaui batas toleransi'));
    });

    test('Kualitas FLAGGED jika simpangan baku mendekati batas toleransi', () {
      // Ambang 500 nT. FLAGGED jika > 375 nT dan <= 500 nT
      final samples = List.generate(
        100,
        (i) => createSample(
          index: i,
          x: 45.0 + (i.isEven ? 0.40 : -0.40), // ~ 400 nT noise
          y: 0.0,
          z: 0.0,
        ),
      );

      final result = service.aggregateStationSamples(samples: samples);

      expect(result.stdDevTotalFieldNt, greaterThan(375.0));
      expect(result.stdDevTotalFieldNt, lessThanOrEqualTo(500.0));
      expect(result.qualityFlag, equals('FLAGGED'));
      expect(result.statusReason, contains('mendekati ambang toleransi'));
    });

    test('Agregasi dengan profil kalibrasi terpasang mengoreksi mean dan total field', () {
      const calProfile = EllipsoidCalibrationResult(
        offsetMicroT: [10.0, 0.0, 0.0],
        matrixA: [
          1.0, 0.0, 0.0,
          0.0, 1.0, 0.0,
          0.0, 0.0, 1.0,
        ],
        residualNt: 5.0,
        stdBeforeNt: 100.0,
        stdAfterNt: 5.0,
        inlierCount: 100,
      );

      final samples = List.generate(
        100,
        (i) => createSample(index: i, x: 55.0, y: 0.0, z: 0.0), // 55 - 10 offset = 45 uT
      );

      final result = service.aggregateStationSamples(
        samples: samples,
        calibrationProfile: calProfile,
      );

      expect(result.rawMeanMicroT[0], closeTo(55.0, 0.1));
      expect(result.calibratedMeanMicroT, isNotNull);
      expect(result.calibratedMeanMicroT![0], closeTo(45.0, 0.1));
      expect(result.meanTotalFieldNt, closeTo(45000.0, 10.0));
      expect(result.qualityFlag, equals('ACCEPTED'));
    });
  });
}
