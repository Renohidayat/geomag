import 'dart:async';

import 'package:flutter/material.dart';

import '../models/magnetometer_sample.dart';
import '../models/sensor_info.dart';
import '../services/magnetometer_service.dart';

/// Layar utama: tampilkan data magnetometer real-time.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MagnetometerService _magnetometerService = MagnetometerService();

  SensorInfo? _sensorInfo;
  MagnetometerSample? _lastSample;
  StreamSubscription<MagnetometerSample>? _subscription;
  bool _isRecording = false;
  String? _errorMessage;

  // Statistik running
  int _displaySampleCount = 0;
  double _sumTotalFieldMicroT = 0.0;
  double _sumTotalFieldSqMicroT = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSensorInfo();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSensorInfo() async {
    try {
      final info = await _magnetometerService.getSensorInfo();
      setState(() => _sensorInfo = info);
    } catch (e) {
      setState(() => _errorMessage = 'Gagal membaca info sensor: $e');
    }
  }

  void _startRecording() {
    _magnetometerService.resetStats();
    _displaySampleCount = 0;
    _sumTotalFieldMicroT = 0.0;
    _sumTotalFieldSqMicroT = 0.0;

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
      },
    );

    setState(() {
      _isRecording = true;
      _errorMessage = null;
    });
  }

  void _stopRecording() {
    _subscription?.cancel();
    _subscription = null;
    setState(() => _isRecording = false);
  }

  /// Simpangan baku total field (mikroTesla).
  double get _stdDevMicroT {
    if (_displaySampleCount < 2) return 0.0;
    final n = _displaySampleCount.toDouble();
    final mean = _sumTotalFieldMicroT / n;
    final variance = (_sumTotalFieldSqMicroT / n) - (mean * mean);
    return variance > 0 ? variance.clamp(0, double.infinity) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoMag'),
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
            if (_lastSample != null) ...[
              _buildMagDataCard(theme),
              const SizedBox(height: 12),
              _buildStatsCard(theme),
              const SizedBox(height: 12),
              _buildDeviceStatusCard(theme),
            ],
            if (!_isRecording && _lastSample == null)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'Tekan tombol di bawah untuk mulai merekam',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRecording ? _stopRecording : _startRecording,
        icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
        label: Text(_isRecording ? 'Berhenti' : 'Mulai Rekam'),
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
            Text('Info Sensor', style: theme.textTheme.titleSmall),
            const Divider(),
            if (info == null)
              const Text('Memuat...')
            else if (!info.available)
              const Text('Magnetometer tidak tersedia')
            else ...[
              _infoRow('Nama', info.name ?? '-'),
              _infoRow('Vendor', info.vendor ?? '-'),
              _infoRow(
                'Tipe',
                info.isUncalibrated ? 'Uncalibrated ✓' : 'Calibrated ⚠',
              ),
              _infoRow(
                'Resolusi',
                info.resolutionMicroT != null
                    ? '${info.resolutionMicroT!.toStringAsFixed(3)} µT'
                    : '-',
              ),
              _infoRow(
                'Laju maks',
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
            Text('Data Magnetometer', style: theme.textTheme.titleSmall),
            const Divider(),
            _infoRow('Bx', '${s.rawXMicroT.toStringAsFixed(2)} µT'),
            _infoRow('By', '${s.rawYMicroT.toStringAsFixed(2)} µT'),
            _infoRow('Bz', '${s.rawZMicroT.toStringAsFixed(2)} µT'),
            const Divider(),
            _infoRow(
              'Total Field',
              '${s.totalFieldMicroT.toStringAsFixed(2)} µT  '
                  '(${s.totalFieldNt.toStringAsFixed(0)} nT)',
            ),
            _infoRow(
              'Akurasi',
              _accuracyLabel(s.accuracy),
            ),
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
            Text('Statistik Sampling', style: theme.textTheme.titleSmall),
            const Divider(),
            _infoRow('Jumlah sampel', '$_displaySampleCount'),
            _infoRow(
              'Laju nyata',
              '${service.actualRateHz.toStringAsFixed(1)} Hz',
            ),
            _infoRow(
              'Jitter',
              '${service.jitterMs.toStringAsFixed(2)} ms',
            ),
            _infoRow(
              'Interval rata-rata',
              '${service.avgIntervalMs.toStringAsFixed(2)} ms',
            ),
            if (_displaySampleCount >= 2)
              _infoRow(
                'σ total field',
                '${(_stdDevMicroT * 1000).toStringAsFixed(1)} nT '
                    '(n=$_displaySampleCount)',
              ),
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
            Text('Status Perangkat', style: theme.textTheme.titleSmall),
            const Divider(),
            _infoRow(
              'Suhu baterai',
              s.batteryTempC >= 0
                  ? '${s.batteryTempC.toStringAsFixed(1)} °C'
                  : 'Tidak tersedia',
            ),
            _infoRow('Mengisi daya', s.isCharging ? 'Ya ⚠' : 'Tidak ✓'),
            _infoRow('Layar', s.isScreenOn ? 'Menyala' : 'Mati'),
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
}
