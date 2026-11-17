import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../models/magnetometer_sample.dart';
import '../models/sensor_info.dart';
import '../services/magnetometer_service.dart';
import '../services/recording_session_service.dart';

/// Layar utama: menampilkan data magnetometer real-time dan metrik instrumen.
class HomeScreen extends StatefulWidget {
  final MagnetometerService? service;
  final AppDatabase? database;

  const HomeScreen({super.key, this.service, this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MagnetometerService _magnetometerService;
  late final AppDatabase _database;
  late final RecordingSessionService _recordingSessionService;

  SensorInfo? _sensorInfo;
  MagnetometerSample? _lastSample;
  StreamSubscription<MagnetometerSample>? _subscription;
  bool _isRecording = false;
  String? _errorMessage;
  String? _exportedFilePath;
  DateTime? _recordingStartTime;
  Timer? _durationTimer;
  Duration _recordingDuration = Duration.zero;

  // Statistik running
  int _displaySampleCount = 0;
  double _sumTotalFieldMicroT = 0.0;
  double _sumTotalFieldSqMicroT = 0.0;

  @override
  void initState() {
    super.initState();
    _magnetometerService = widget.service ?? MagnetometerService();
    _database = widget.database ?? AppDatabase();
    _recordingSessionService = RecordingSessionService(database: _database);
    _loadSensorInfo();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _subscription?.cancel();
    if (widget.database == null) {
      _database.close();
    }
    super.dispose();
  }

  Future<void> _loadSensorInfo() async {
    try {
      final info = await _magnetometerService.getSensorInfo();
      if (mounted) setState(() => _sensorInfo = info);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Gagal membaca info sensor: $e');
    }
  }

  Future<void> _startRecording() async {
    _magnetometerService.resetStats();
    _displaySampleCount = 0;
    _sumTotalFieldMicroT = 0.0;
    _sumTotalFieldSqMicroT = 0.0;
    _recordingStartTime = DateTime.now();
    _recordingDuration = Duration.zero;
    _exportedFilePath = null;

    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_recordingStartTime != null && mounted) {
        setState(() {
          _recordingDuration = DateTime.now().difference(_recordingStartTime!);
        });
      }
    });

    await _recordingSessionService.startSession(
      sampleStream: _magnetometerService.sampleStream,
    );

    _subscription = _magnetometerService.sampleStream.listen(
      (sample) {
        _displaySampleCount++;
        final tf = sample.totalFieldMicroT;
        _sumTotalFieldMicroT += tf;
        _sumTotalFieldSqMicroT += tf * tf;

        setState(() => _lastSample = sample);
      },
      onError: (error) {
        setState(() {
          _errorMessage = 'Error sensor: $error';
          _isRecording = false;
        });
        _durationTimer?.cancel();
      },
    );

    setState(() {
      _isRecording = true;
      _errorMessage = null;
    });
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _subscription?.cancel();
    _subscription = null;
    setState(() => _isRecording = false);
    await _recordingSessionService.stopSession();
  }

  Future<void> _exportCsv() async {
    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final file = await _recordingSessionService.exportCurrentStationToCsv(outputDir);
      if (mounted) {
        setState(() => _exportedFilePath = file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV berhasil diekspor: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Simpangan baku total field (mikroTesla).
  double get _stdDevMicroT {
    if (_displaySampleCount < 2) return 0.0;
    final n = _displaySampleCount.toDouble();
    final mean = _sumTotalFieldMicroT / n;
    final variance = (_sumTotalFieldSqMicroT / n) - (mean * mean);
    return variance > 0 ? variance.clamp(0, double.infinity) : 0.0;
  }

  /// Simpangan baku total field dalam nanoTesla.
  double get _stdDevNt => _stdDevMicroT * 1000.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoMag - Survei Magnetik'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSensorInfoCard(theme),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
            if (_exportedFilePath != null)
              Card(
                color: Colors.green.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'File CSV tersimpan:\n$_exportedFilePath',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_lastSample != null) ...[
              _buildMagDataCard(theme),
              const SizedBox(height: 12),
              _buildStatsCard(theme),
              const SizedBox(height: 12),
              _buildDeviceStatusCard(theme),
              if (!_isRecording && _displaySampleCount > 0) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.file_download),
                  label: const Text('Ekspor Data Stasiun ke CSV'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ],
            if (!_isRecording && _lastSample == null)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.sensors,
                        size: 64,
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tekan tombol di bawah untuk mulai streaming sensor',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRecording ? _stopRecording : _startRecording,
        icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
        label: Text(
          _isRecording
              ? 'Berhenti (${_formatDuration(_recordingDuration)})'
              : 'Mulai Rekam',
        ),
        backgroundColor: _isRecording
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        foregroundColor: _isRecording
            ? theme.colorScheme.onError
            : theme.colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildSensorInfoCard(ThemeData theme) {
    final info = _sensorInfo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Info Sensor', style: theme.textTheme.titleSmall),
                if (info != null && info.available)
                  Chip(
                    label: Text(
                      info.isUncalibrated ? 'Uncalibrated' : 'Calibrated OS',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: info.isUncalibrated
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const Divider(),
            if (info == null)
              const Text('Memuat...')
            else if (!info.available)
              const Text('Magnetometer tidak tersedia pada perangkat ini')
            else ...[
              _infoRow('Nama', info.name ?? '-'),
              _infoRow('Vendor', info.vendor ?? '-'),
              _infoRow(
                'Resolusi',
                info.resolutionMicroT != null
                    ? '${info.resolutionMicroT!.toStringAsFixed(3)} µT'
                    : '-',
              ),
              _infoRow(
                'Laju maks hardware',
                info.maxRateHz != null
                    ? '${info.maxRateHz!.toStringAsFixed(0)} Hz'
                    : '-',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMagDataCard(ThemeData theme) {
    final s = _lastSample!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data Medan Magnetik (Real-time)',
                style: theme.textTheme.titleSmall),
            const Divider(),
            _infoRow('Bx (komponen X)', '${s.rawXMicroT.toStringAsFixed(2)} µT'),
            _infoRow('By (komponen Y)', '${s.rawYMicroT.toStringAsFixed(2)} µT'),
            _infoRow('Bz (komponen Z)', '${s.rawZMicroT.toStringAsFixed(2)} µT'),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Field (F)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${s.totalFieldNt.toStringAsFixed(0)} nT  '
                  '(${s.totalFieldMicroT.toStringAsFixed(2)} µT)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _infoRow('Akurasi OS', _accuracyLabel(s.accuracy)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final service = _magnetometerService;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistik Sampling & Stabilitas',
                style: theme.textTheme.titleSmall),
            const Divider(),
            _infoRow('Jumlah sampel', '$_displaySampleCount'),
            _infoRow(
              'Laju nyata',
              '${service.actualRateHz.toStringAsFixed(1)} Hz',
            ),
            _infoRow(
              'Jitter antar-sampel',
              '${service.jitterMs.toStringAsFixed(2)} ms',
            ),
            _infoRow(
              'Interval rata-rata',
              '${service.avgIntervalMs.toStringAsFixed(2)} ms',
            ),
            if (_displaySampleCount >= 2) ...[
              const Divider(),
              _infoRow(
                'Simpangan baku σ',
                '${_stdDevNt.toStringAsFixed(1)} nT (n=$_displaySampleCount)',
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (_stdDevNt / 1000.0).clamp(0.0, 1.0),
                backgroundColor: Colors.green.withValues(alpha: 0.2),
                color: _stdDevNt < 300
                    ? Colors.green
                    : (_stdDevNt < 800 ? Colors.orange : Colors.red),
              ),
              const SizedBox(height: 4),
              Text(
                _stdDevNt < 300
                    ? 'Sinyal tenang (σ < 300 nT)'
                    : (_stdDevNt < 800
                        ? 'Noise sedang (300–800 nT)'
                        : 'Noise tinggi / ada gangguan (> 800 nT)'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _stdDevNt < 300
                      ? Colors.green
                      : (_stdDevNt < 800 ? Colors.orange : Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard(ThemeData theme) {
    final s = _lastSample!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status Kondisi Perangkat', style: theme.textTheme.titleSmall),
            const Divider(),
            _infoRow(
              'Suhu baterai',
              s.batteryTempC >= 0
                  ? '${s.batteryTempC.toStringAsFixed(1)} °C'
                  : 'Tidak tersedia',
            ),
            _infoRow(
              'Status pengisian daya',
              s.isCharging
                  ? 'Mengisi daya (PERINGATAN: arus charging merusak medan!)'
                  : 'Baterai (Aman ✓)',
            ),
            _infoRow('Status layar', s.isScreenOn ? 'Menyala' : 'Mati'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  String _accuracyLabel(int accuracy) {
    switch (accuracy) {
      case 3:
        return 'Tinggi (3)';
      case 2:
        return 'Sedang (2)';
      case 1:
        return 'Rendah (1)';
      default:
        return 'Tidak andal (0)';
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
