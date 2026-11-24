import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:geomag/database/app_database.dart';
import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/services/sensor/magnetometer_service.dart';

/// Titik data ringkasan kurva drift harian (time-series).
class BaseDriftPoint {
  final DateTime time;
  final int timestampNs;
  final double totalFieldNt;
  final double relativeDeltaNt;

  const BaseDriftPoint({
    required this.time,
    required this.timestampNs,
    required this.totalFieldNt,
    required this.relativeDeltaNt,
  });
}

/// Service untuk mengelola perekaman kontinu base station, batching database, dan kurva variasi harian.
class BaseStationService {
  final AppDatabase database;
  final MagnetometerService magnetometerService;
  final int batchBufferSize;

  StreamSubscription<MagnetometerSample>? _subscription;
  final List<SamplesCompanion> _buffer = [];

  bool _isRecording = false;
  String? _currentSurveyId;
  String? _currentStationId;
  DateTime? _recordingStartTime;

  double? _baselineFieldNt;
  final List<BaseDriftPoint> _driftPoints = [];
  int _totalRecordedCount = 0;

  double _minFieldNt = double.infinity;
  double _maxFieldNt = double.negativeInfinity;
  double _sumFieldNt = 0.0;
  double _sumSqDiffFieldNt = 0.0;

  BaseStationService({
    required this.database,
    required this.magnetometerService,
    this.batchBufferSize = 50,
  });

  bool get isRecording => _isRecording;
  String? get currentSurveyId => _currentSurveyId;
  String? get currentStationId => _currentStationId;
  DateTime? get recordingStartTime => _recordingStartTime;
  int get totalRecordedCount => _totalRecordedCount;
  List<BaseDriftPoint> get driftPoints => List.unmodifiable(_driftPoints);
  double? get baselineFieldNt => _baselineFieldNt;
  double get minFieldNt => _minFieldNt.isFinite ? _minFieldNt : 0.0;
  double get maxFieldNt => _maxFieldNt.isFinite ? _maxFieldNt : 0.0;
  double get driftRangeNt => (maxFieldNt - minFieldNt).clamp(0.0, double.infinity);
  double get meanFieldNt => _totalRecordedCount > 0 ? _sumFieldNt / _totalRecordedCount : 0.0;
  double get stdDevFieldNt => _totalRecordedCount > 1
      ? sqrt(_sumSqDiffFieldNt / (_totalRecordedCount - 1))
      : 0.0;

  /// Memulai sesi perekaman base station.
  Future<void> startBaseRecording({
    required String surveyId,
    required String stationId,
  }) async {
    if (_isRecording) return;

    _isRecording = true;
    _currentSurveyId = surveyId;
    _currentStationId = stationId;
    _recordingStartTime = DateTime.now();
    _buffer.clear();
    _driftPoints.clear();
    _totalRecordedCount = 0;
    _baselineFieldNt = null;
    _minFieldNt = double.infinity;
    _maxFieldNt = double.negativeInfinity;
    _sumFieldNt = 0.0;
    _sumSqDiffFieldNt = 0.0;

    _subscription = magnetometerService.sampleStream.listen((sample) {
      _processSample(sample);
    });
  }

  void _processSample(MagnetometerSample sample) {
    if (!_isRecording || _currentStationId == null) return;

    final stationId = _currentStationId!;
    final totalNt = sample.totalFieldNt;
    _totalRecordedCount++;

    // Inisialisasi baseline referensi B0 (rata-rata sampel awal)
    _baselineFieldNt ??= totalNt;

    if (totalNt < _minFieldNt) _minFieldNt = totalNt;
    if (totalNt > _maxFieldNt) _maxFieldNt = totalNt;

    _sumFieldNt += totalNt;
    final currentMean = _sumFieldNt / _totalRecordedCount;
    final diff = totalNt - currentMean;
    _sumSqDiffFieldNt += diff * diff;

    // Catat drift point secara teratur (downsampling untuk grafik: maks 1 titik per ~10 sampel atau setiap 0.2 detik)
    if (_totalRecordedCount % 10 == 1 || _driftPoints.isEmpty) {
      final now = DateTime.now();
      final relDelta = totalNt - _baselineFieldNt!;
      _driftPoints.add(
        BaseDriftPoint(
          time: now,
          timestampNs: sample.timestampNs,
          totalFieldNt: totalNt,
          relativeDeltaNt: relDelta,
        ),
      );
    }

    // Tambah ke batch buffer
    final sampleId = '${stationId}_${sample.timestampNs}_$_totalRecordedCount';
    _buffer.add(
      SamplesCompanion.insert(
        id: sampleId,
        stationId: stationId,
        timestampNs: BigInt.from(sample.timestampNs),
        rawXMicroT: sample.rawXMicroT,
        rawYMicroT: sample.rawYMicroT,
        rawZMicroT: sample.rawZMicroT,
        biasXMicroT: sample.biasXMicroT,
        biasYMicroT: sample.biasYMicroT,
        biasZMicroT: sample.biasZMicroT,
        accuracy: sample.accuracy,
        isUncalibrated: sample.isUncalibrated,
        batteryTempC: sample.batteryTempC,
        isCharging: sample.isCharging,
        isScreenOn: sample.isScreenOn,
      ),
    );

    if (_buffer.length >= batchBufferSize) {
      _flushBuffer();
    }
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    final toFlush = List<SamplesCompanion>.from(_buffer);
    _buffer.clear();
    await database.insertSamplesBatch(toFlush);
  }

  /// Menghentikan sesi perekaman dan menyimpan hasil akhir stasiun base.
  Future<void> stopBaseRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    await _subscription?.cancel();
    _subscription = null;

    // Flush sisa buffer
    await _flushBuffer();

    final stationId = _currentStationId;
    if (stationId != null && _totalRecordedCount > 0) {
      // Simpan ringkasan StationResults
      await database.saveStationResult(
        StationResultsCompanion.insert(
          id: 'res_$stationId',
          stationId: stationId,
          totalFieldMeanNt: meanFieldNt,
          totalFieldStdNt: stdDevFieldNt,
          sampleCount: _totalRecordedCount,
          isAccepted: true,
          rejectionReason: const Value.absent(),
        ),
      );
    }
  }

  /// Mengekspor seluruh sampel base station ke file CSV.
  Future<File> exportBaseStationCsv({
    required String filePath,
    double? latitude,
    double? longitude,
  }) async {
    final stationId = _currentStationId;
    if (stationId == null) {
      throw StateError('Tidak ada stasiun base aktif untuk diekspor');
    }

    final samples = await database.getSamplesForStation(stationId);
    final buffer = StringBuffer();

    // Header metadata dan kolom
    buffer.writeln('# GeoMag Base Station Diurnal Record');
    buffer.writeln('# StationId: $stationId');
    buffer.writeln('# Latitude: ${latitude ?? 0.0}, Longitude: ${longitude ?? 0.0}');
    buffer.writeln('# BaselineB0: ${_baselineFieldNt?.toStringAsFixed(2) ?? "0.0"} nT');
    buffer.writeln(
      'timestamp_iso,timestamp_ns,raw_x_microt,raw_y_microt,raw_z_microt,total_field_nt,delta_b_nt,battery_temp_c',
    );

    final b0 = _baselineFieldNt ?? (samples.isNotEmpty ? _calcTotalNt(samples.first) : 0.0);

    for (final s in samples) {
      final totalNt = sqrt(
            s.rawXMicroT * s.rawXMicroT +
                s.rawYMicroT * s.rawYMicroT +
                s.rawZMicroT * s.rawZMicroT,
          ) *
          1000.0;
      final deltaB = totalNt - b0;
      final isoTime = s.recordedAt.toIso8601String();

      buffer.writeln(
        '$isoTime,${s.timestampNs},${s.rawXMicroT.toStringAsFixed(4)},${s.rawYMicroT.toStringAsFixed(4)},${s.rawZMicroT.toStringAsFixed(4)},${totalNt.toStringAsFixed(2)},${deltaB.toStringAsFixed(2)},${s.batteryTempC.toStringAsFixed(1)}',
      );
    }

    final file = File(filePath);
    await file.parent.create(recursive: true);
    return await file.writeAsString(buffer.toString());
  }

  double _calcTotalNt(Sample s) {
    return sqrt(
          s.rawXMicroT * s.rawXMicroT +
              s.rawYMicroT * s.rawYMicroT +
              s.rawZMicroT * s.rawZMicroT,
        ) *
        1000.0;
  }
}
