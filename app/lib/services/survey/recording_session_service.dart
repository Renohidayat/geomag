import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/services/export/csv_export_service.dart';

/// Mengelola sesi perekaman magnetometer, buffering batch ke database SQLite,
/// dan ekspor CSV.
class RecordingSessionService {
  final AppDatabase database;
  final CsvExportService csvExportService;

  final int batchSize;
  final List<SamplesCompanion> _buffer = [];
  StreamSubscription<MagnetometerSample>? _subscription;

  String? _activeStationId;
  String? _activeSurveyId;
  int _sampleCounter = 0;
  bool _isRecording = false;

  RecordingSessionService({
    required this.database,
    CsvExportService? csvExportService,
    this.batchSize = 50,
  }) : csvExportService = csvExportService ?? CsvExportService();

  bool get isRecording => _isRecording;
  String? get activeSurveyId => _activeSurveyId;
  String? get activeStationId => _activeStationId;
  int get recordedSampleCount => _sampleCounter;

  /// Memulai sesi perekaman untuk stasiun tertentu.
  /// Jika [surveyId] atau [stationId] null, sesi cepat (quick session) akan otomatis dibuat.
  Future<void> startSession({
    required Stream<MagnetometerSample> sampleStream,
    String? surveyId,
    String? stationId,
    String? deviceId,
  }) async {
    if (_isRecording) return;

    final targetDeviceId = deviceId ?? 'default-device';
    final targetSurveyId = surveyId ?? 'quick-survey-${DateTime.now().millisecondsSinceEpoch}';
    final targetStationId = stationId ?? 'stn-${DateTime.now().millisecondsSinceEpoch}';

    // Pastikan device dan survey terdaftar di database (foreign keys)
    await database.insertDevice(
      DevicesCompanion(
        id: Value(targetDeviceId),
        model: const Value('Android Device'),
        androidVersion: const Value('Unknown'),
        magnetometerChip: const Value('Magnetometer'),
      ),
    );

    await database.insertSurvey(
      SurveysCompanion(
        id: Value(targetSurveyId),
        deviceId: Value(targetDeviceId),
        name: const Value('Sesi Cepat'),
        date: Value(DateTime.now()),
        mode: const Value('rover'),
      ),
    );

    await database.insertStation(
      StationsCompanion(
        id: Value(targetStationId),
        surveyId: Value(targetSurveyId),
        sequenceNumber: const Value(1),
      ),
    );

    _activeSurveyId = targetSurveyId;
    _activeStationId = targetStationId;
    _sampleCounter = 0;
    _buffer.clear();
    _isRecording = true;

    _subscription = sampleStream.listen(
      (sample) => _onSampleReceived(sample, targetStationId),
      onError: (e) {
        _isRecording = false;
      },
    );
  }

  void _onSampleReceived(MagnetometerSample sample, String stationId) {
    _sampleCounter++;
    final companion = SamplesCompanion(
      id: Value('$stationId-$_sampleCounter-${sample.timestampNs}'),
      stationId: Value(stationId),
      timestampNs: Value(BigInt.from(sample.timestampNs)),
      rawXMicroT: Value(sample.rawXMicroT),
      rawYMicroT: Value(sample.rawYMicroT),
      rawZMicroT: Value(sample.rawZMicroT),
      biasXMicroT: Value(sample.biasXMicroT),
      biasYMicroT: Value(sample.biasYMicroT),
      biasZMicroT: Value(sample.biasZMicroT),
      accuracy: Value(sample.accuracy),
      isUncalibrated: Value(sample.isUncalibrated),
      batteryTempC: Value(sample.batteryTempC),
      isCharging: Value(sample.isCharging),
      isScreenOn: Value(sample.isScreenOn),
    );

    _buffer.add(companion);

    if (_buffer.length >= batchSize) {
      _flushBuffer();
    }
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    final toInsert = List<SamplesCompanion>.from(_buffer);
    _buffer.clear();
    await database.insertSamplesBatch(toInsert);
  }

  /// Menghentikan sesi perekaman dan memastikan semua sisa buffer tersimpan ke database.
  Future<void> stopSession() async {
    if (!_isRecording) return;
    await _subscription?.cancel();
    _subscription = null;
    await _flushBuffer();
    _isRecording = false;
  }

  /// Mengambil semua sampel dari database untuk stasiun yang baru saja direkam dan mengekspornya ke CSV.
  Future<File> exportCurrentStationToCsv(Directory outputDirectory) async {
    final stationId = _activeStationId;
    if (stationId == null) {
      throw StateError('Belum ada stasiun aktif untuk diekspor');
    }

    // Pastikan buffer sudah masuk ke database
    await _flushBuffer();

    final samples = await database.getSamplesForStation(stationId);
    return csvExportService.exportStationSamplesToCsv(
      stationId: stationId,
      samples: samples,
      outputDirectory: outputDirectory,
    );
  }
}
