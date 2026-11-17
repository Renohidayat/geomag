import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/services/ellipsoid_calibration_service.dart';

List<List<double>> generateSpherePoints({
  int count = 100,
  double radius = 45.0,
}) {
  final points = <List<double>>[];
  final goldenRatio = (1.0 + sqrt(5.0)) / 2.0;

  for (var i = 0; i < count; i++) {
    final theta = 2.0 * pi * i / goldenRatio;
    final phi = acos(1.0 - 2.0 * (i + 0.5) / count);

    final x = radius * sin(phi) * cos(theta);
    final y = radius * sin(phi) * sin(theta);
    final z = radius * cos(phi);

    points.add([x, y, z]);
  }
  return points;
}

void main() {
  late EllipsoidCalibrationService service;

  setUp(() {
    service = EllipsoidCalibrationService();
  });

  group('EllipsoidCalibrationService', () {
    test('Fit bola sempurna menghasilkan offset nol dan matriks identitas', () {
      const bRef = 45.0; // uT
      final spherePoints = generateSpherePoints(count: 100, radius: bRef);

      final result = service.fitEllipsoidRobust(
        pointsMicroT: spherePoints,
        bRefMicroT: bRef,
      );

      // Offset mendekati 0.0
      expect(result.offsetMicroT[0], closeTo(0.0, 0.01));
      expect(result.offsetMicroT[1], closeTo(0.0, 0.01));
      expect(result.offsetMicroT[2], closeTo(0.0, 0.01));

      // Diagonal matriks A mendekati 1.0, off-diagonal mendekati 0.0
      expect(result.matrixA[0], closeTo(1.0, 0.01)); // a11
      expect(result.matrixA[4], closeTo(1.0, 0.01)); // a22
      expect(result.matrixA[8], closeTo(1.0, 0.01)); // a33
      expect(result.matrixA[1].abs(), lessThan(0.01));

      // Residu sangat kecil (< 1.0 nT)
      expect(result.residualNt, lessThan(1.0));
      expect(result.stdAfterNt, lessThan(1.0));
    });

    test('Fit data sintetis dengan offset hard iron dan deformasi skala', () {
      const bRef = 45.0; // uT
      const trueOffset = [12.5, -8.2, 5.0];
      const scaleX = 1.10;
      const scaleY = 0.95;
      const scaleZ = 1.05;

      final sphere = generateSpherePoints(count: 150, radius: bRef);
      final distorted = sphere.map((p) {
        return [
          p[0] * scaleX + trueOffset[0],
          p[1] * scaleY + trueOffset[1],
          p[2] * scaleZ + trueOffset[2],
        ];
      }).toList();

      final result = service.fitEllipsoidRobust(
        pointsMicroT: distorted,
        bRefMicroT: bRef,
      );

      // Verifikasi offset terecover dengan akurasi tinggi (< 0.1 uT)
      expect(result.offsetMicroT[0], closeTo(trueOffset[0], 0.1));
      expect(result.offsetMicroT[1], closeTo(trueOffset[1], 0.1));
      expect(result.offsetMicroT[2], closeTo(trueOffset[2], 0.1));

      // Simpangan baku sesudah kalibrasi harus jauh lebih kecil dari sebelum
      expect(result.stdAfterNt, lessThan(10.0));
      expect(result.stdBeforeNt, greaterThan(1000.0));

      // Residu rata-rata < 10 nT
      expect(result.residualNt, lessThan(10.0));
      expect(result.inlierCount, equals(150));
    });

    test('Robust fitting berhasil menolak outlier ekstrem', () {
      const bRef = 45.0;
      const trueOffset = [5.0, 3.0, -4.0];
      final sphere = generateSpherePoints(count: 100, radius: bRef);
      final points = sphere.map((p) {
        return [
          p[0] + trueOffset[0],
          p[1] + trueOffset[1],
          p[2] + trueOffset[2],
        ];
      }).toList();

      // Tambahkan 5 outlier ekstrem
      points.addAll([
        [150.0, 150.0, 150.0],
        [-100.0, 80.0, -90.0],
        [80.0, -120.0, 50.0],
        [0.0, 200.0, -50.0],
        [-150.0, -100.0, 100.0],
      ]);

      final result = service.fitEllipsoidRobust(
        pointsMicroT: points,
        bRefMicroT: bRef,
      );

      // Outlier harus ditolak
      expect(result.inlierCount, lessThanOrEqualTo(100));
      expect(result.offsetMicroT[0], closeTo(trueOffset[0], 0.1));
      expect(result.offsetMicroT[1], closeTo(trueOffset[1], 0.1));
      expect(result.offsetMicroT[2], closeTo(trueOffset[2], 0.1));
      expect(result.residualNt, lessThan(10.0));
    });

    test('applyCorrection dan calibratedTotalFieldNt mengoreksi sampel realtime', () {
      const bRef = 45.0;
      final sphere = generateSpherePoints(count: 80, radius: bRef);
      final distorted = sphere.map((p) => [p[0] + 10.0, p[1] - 5.0, p[2] + 2.0]).toList();

      final result = service.fitEllipsoidRobust(
        pointsMicroT: distorted,
        bRefMicroT: bRef,
      );

      // Ambil sampel mentah di kutub
      final rawPt = [10.0, -5.0, bRef + 2.0];
      final calVector = result.applyCorrection(rawPt[0], rawPt[1], rawPt[2]);
      final totalNt = result.calibratedTotalFieldNt(rawPt[0], rawPt[1], rawPt[2]);

      expect(calVector[0], closeTo(0.0, 0.1));
      expect(calVector[1], closeTo(0.0, 0.1));
      expect(calVector[2], closeTo(bRef, 0.1));
      expect(totalNt, closeTo(bRef * 1000.0, 100.0));
    });

    test('saveCalibrationProfile menyimpan ke database Drift dengan format CSV matriks A', () async {
      final db = AppDatabase(NativeDatabase.memory());
      const deviceId = 'test-phone';

      // Insert device terlebih dahulu agar relasi foreign key terpenuhi
      await db.insertDevice(
        const DevicesCompanion(
          id: Value(deviceId),
          model: Value('Pixel 7'),
          androidVersion: Value('14'),
          magnetometerChip: Value('AK09918'),
        ),
      );

      const result = EllipsoidCalibrationResult(
        offsetMicroT: [10.5, -4.2, 2.1],
        matrixA: [
          1.01, 0.01, 0.0,
          0.01, 0.98, 0.02,
          0.0, 0.02, 1.03,
        ],
        residualNt: 8.5,
        stdBeforeNt: 4500.0,
        stdAfterNt: 7.2,
        inlierCount: 120,
      );

      final rowId = await service.saveCalibrationProfile(
        database: db,
        deviceId: deviceId,
        result: result,
        temperatureC: 32.5,
        casingAttached: false,
      );

      expect(rowId, greaterThan(0));

      final latest = await db.getLatestCalibrationProfile(deviceId);
      expect(latest, isNotNull);
      expect(latest!.deviceId, equals(deviceId));
      expect(latest.hardIronBxMicroT, equals(10.5));
      expect(latest.hardIronByMicroT, equals(-4.2));
      expect(latest.hardIronBzMicroT, equals(2.1));
      expect(latest.residualNt, equals(8.5));
      expect(latest.matrixA, contains('1.01000000'));
      expect(latest.casingAttached, isFalse);

      await db.close();
    });
  });
}
