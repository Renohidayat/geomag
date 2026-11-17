import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/magnetometer_sample.dart';
import '../services/allan_deviation_service.dart';
import '../services/magnetometer_service.dart';

/// Layar untuk menguji lantai noise magnetometer HP diam dan menghitung Allan deviation.
class NoiseTestScreen extends StatefulWidget {
  final MagnetometerService? service;
  final AppDatabase? database;
  final int testDurationSeconds;

  const NoiseTestScreen({
    super.key,
    this.service,
    this.database,
    this.testDurationSeconds = 30, // Default 30 detik untuk pengujian interaktif cepat
  });

  @override
  State<NoiseTestScreen> createState() => _NoiseTestScreenState();
}

class _NoiseTestScreenState extends State<NoiseTestScreen> {
  late final MagnetometerService _magnetometerService;
  late final AppDatabase _database;
  final AllanDeviationService _allanService = AllanDeviationService();

  StreamSubscription<MagnetometerSample>? _subscription;
  Timer? _countdownTimer;

  bool _isRunning = false;
  int _remainingSeconds = 0;
  final List<double> _totalFieldNtList = [];

  AllanDeviationResult? _result;
  String? _statusMessage;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _magnetometerService = widget.service ?? MagnetometerService();
    _database = widget.database ?? AppDatabase();
    _remainingSeconds = widget.testDurationSeconds;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _subscription?.cancel();
    if (widget.database == null) {
      _database.close();
    }
    super.dispose();
  }

  void _startNoiseTest() {
    setState(() {
      _isRunning = true;
      _isSaved = false;
      _result = null;
      _statusMessage = null;
      _totalFieldNtList.clear();
      _remainingSeconds = widget.testDurationSeconds;
    });

    _subscription?.cancel();
    _subscription = _magnetometerService.sampleStream.listen((sample) {
      _totalFieldNtList.add(sample.totalFieldNt);
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _finishNoiseTest();
      }
    });
  }

  void _finishNoiseTest() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _subscription?.cancel();
    _subscription = null;

    if (_totalFieldNtList.length < 9) {
      setState(() {
        _isRunning = false;
        _statusMessage = 'Sampel tidak cukup untuk menghitung Allan deviation';
      });
      return;
    }

    try {
      final rateHz = _totalFieldNtList.length / widget.testDurationSeconds;
      final res = _allanService.computeAllanDeviation(
        values: _totalFieldNtList,
        rateHz: rateHz,
      );

      setState(() {
        _isRunning = false;
        _result = res;
        _statusMessage = 'Uji lantai noise selesai';
      });
    } catch (e) {
      setState(() {
        _isRunning = false;
        _statusMessage = 'Error menghitung Allan deviation: $e';
      });
    }
  }

  Future<void> _saveToDeviceProfile() async {
    final res = _result;
    if (res == null) return;

    try {
      const deviceId = 'default-device';
      await _database.insertDevice(
        DevicesCompanion(
          id: const Value(deviceId),
          model: const Value('Android Device'),
          androidVersion: const Value('Current'),
          magnetometerChip: const Value('Magnetometer'),
          noiseFloorNt: Value(res.noiseFloor),
        ),
      );

      setState(() => _isSaved = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lantai noise ${res.noiseFloor.toStringAsFixed(1)} nT berhasil disimpan ke profil HP',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan ke database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.testDurationSeconds > 0
        ? (widget.testDurationSeconds - _remainingSeconds) /
            widget.testDurationSeconds
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uji Lantai Noise HP'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructionCard(theme),
            const SizedBox(height: 16),
            if (_isRunning) _buildRunningCard(theme, progress),
            if (_statusMessage != null && !_isRunning)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              _buildResultCard(theme, _result!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _isRunning ? null : _startNoiseTest,
          icon: Icon(_isRunning ? Icons.hourglass_top : Icons.play_arrow),
          label: Text(
            _isRunning
                ? 'Merekam Diam (${_remainingSeconds}s)...'
                : 'Mulai Uji Lantai Noise (${widget.testDurationSeconds}s)',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Protokol Uji Noise', style: theme.textTheme.titleMedium),
              ],
            ),
            const Divider(),
            const Text(
              '1. Letakkan HP diam di atas permukaan non-magnetik (meja kayu/lantai).\n'
              '2. Jauhkan dari benda logam, charger, kabel listrik, dan laptop.\n'
              '3. Jangan sentuh atau gerakkan HP selama perekaman berlangsung.\n'
              '4. Aplikasi akan menghitung Allan Deviation untuk mengukur batas bawah noise instrumen.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunningCard(ThemeData theme, double progress) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Perekaman Diam Sedang Berjalan',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 12),
            Text(
              'Sisa Waktu: $_remainingSeconds detik',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Text('Sampel terkumpul: ${_totalFieldNtList.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme, AllanDeviationResult res) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil Pengukuran Allan Deviation',
                style: theme.textTheme.titleMedium),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lantai Noise Terukur:'),
                Text(
                  '${res.noiseFloor.toStringAsFixed(1)} nT',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Waktu integrasi optimal (tau): ${res.optimalTauSeconds.toStringAsFixed(2)} detik',
            ),
            Text('Titik kurva Allan dievaluasi: ${res.tauSeconds.length}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Prinsip PRD: Anomali geologi di bawah ${res.noiseFloor.toStringAsFixed(0)} nT tidak dapat diklaim sebagai sinyal valid pada perangkat ini.',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaved ? null : _saveToDeviceProfile,
                icon: Icon(_isSaved ? Icons.check : Icons.save),
                label: Text(
                  _isSaved
                      ? 'Tersimpan di Profil HP ✓'
                      : 'Simpan Lantai Noise ke Profil HP',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
