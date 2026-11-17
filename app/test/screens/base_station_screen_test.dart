import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/sensor_info.dart';
import 'package:geomag/screens/base_station_screen.dart';
import 'package:geomag/services/base_station_service.dart';
import 'package:geomag/services/magnetometer_service.dart';

class MockBaseScreenMagService extends MagnetometerService {
  final _controller = StreamController<MagnetometerSample>.broadcast();

  @override
  Stream<MagnetometerSample> get sampleStream => _controller.stream;

  @override
  Future<SensorInfo> getSensorInfo() async => const SensorInfo(
        available: true,
        isUncalibrated: true,
        name: 'Mock Base Magnetometer',
      );

  void emitSamples(int count, double baseMicroT, double step) {
    for (var i = 0; i < count; i++) {
      _controller.add(
        MagnetometerSample(
          timestampNs: 1000000000 + i * 20000000,
          rawXMicroT: baseMicroT + (i * step),
          rawYMicroT: 0.0,
          rawZMicroT: 0.0,
          biasXMicroT: 0.0,
          biasYMicroT: 0.0,
          biasZMicroT: 0.0,
          accuracy: 3,
          isUncalibrated: true,
          batteryTempC: 30.0,
          isCharging: false,
          isScreenOn: true,
        ),
      );
    }
  }

  void close() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'BaseStationScreen alur mulai rekam base station, visualisasi drift, berhenti rekam, dan ekspor CSV',
      (tester) async {
    final mockService = MockBaseScreenMagService();
    final testDb = AppDatabase(NativeDatabase.memory());
    final baseService = BaseStationService(
      database: testDb,
      magnetometerService: mockService,
      batchBufferSize: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BaseStationScreen(
          service: mockService,
          database: testDb,
          baseStationService: baseService,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi UI awal
    expect(find.text('Mode Base Station'), findsOneWidget);
    expect(find.text('BASE STATION STANDBY'), findsOneWidget);
    expect(find.text('Mulai Rekam Base Station'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(baseService.driftPoints, isEmpty);

    // Tekan tombol Mulai Rekam Base Station
    final startBtn = find.text('Mulai Rekam Base Station');
    await tester.ensureVisible(startBtn);
    await tester.tap(startBtn);
    await tester.pumpAndSettle();

    expect(find.text('SEDANG MEREKAM BASE STATION'), findsOneWidget);
    expect(find.text('Hentikan Perekaman Base Station'), findsOneWidget);

    // Pancarkan 15 sampel medan kontinu
    mockService.emitSamples(15, 45.0, 0.05);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Verifikasi kurva drift telah menerima titik sampel
    expect(baseService.driftPoints, isNotEmpty);

    // Hentikan Perekaman
    final stopBtn = find.text('Hentikan Perekaman Base Station');
    await tester.ensureVisible(stopBtn);
    await tester.tap(stopBtn);
    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(baseService.isRecording, isFalse);
    expect(find.text('Ekspor Dataset Base Station ke CSV'), findsOneWidget);

    // Tunggu SnackBar dismiss agar tidak menghalangi tap
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Ekspor CSV
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final exportBtn = find.byType(OutlinedButton);
    expect(exportBtn, findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(exportBtn);
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('Terekspor:'), findsOneWidget);

    // Verifikasi di database
    final stations = await testDb.select(testDb.stations).get();
    expect(stations.length, equals(1));

    final samples = await testDb.select(testDb.samples).get();
    expect(samples.length, equals(15));

    mockService.close();
    await testDb.close();
  });
}
