import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/sensor_info.dart';
import '../services/magnetometer_service.dart';

/// Layar Pengaturan & Preferensi aplikasi GeoMag.
class SettingsScreen extends StatefulWidget {
  final AppDatabase database;
  final MagnetometerService? service;

  const SettingsScreen({
    super.key,
    required this.database,
    this.service,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SensorInfo? _sensorInfo;
  bool _useMicroT = true;
  double _highThresholdMicroT = 58.0;
  double _mediumThresholdMicroT = 48.0;

  int _surveyCount = 0;
  int _stationCount = 0;
  int _sampleCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadSensorInfo();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await widget.database.getDatabaseStats();
      if (mounted) {
        setState(() {
          _surveyCount = stats.surveys;
          _stationCount = stats.stations;
          _sampleCount = stats.samples;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadSensorInfo() async {
    if (widget.service != null) {
      try {
        final info = await widget.service!.getSensorInfo();
        if (mounted) {
          setState(() => _sensorInfo = info);
        }
      } catch (_) {}
    }
  }

  Future<void> _confirmFactoryReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Reset Seluruh Data?'),
          ],
        ),
        content: const Text(
          'Tindakan ini akan menghapus permanen semua data survei, titik stasiun, '
          'sampel mentah, dan profil kalibrasi di HP ini.\n\n'
          'Aplikasi akan kembali bersih dari nol seperti baru dipasang. Apakah Anda yakin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.database.factoryResetDatabase();
        await _loadStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Semua data aplikasi berhasil direset bersih dari nol!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mereset database: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Preferensi Tampilan Satuan
          _buildSectionHeader('Tampilan Satuan Medan Magnet', theme),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('MikroTesla (µT) • Ramah Awam', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.speed, size: 16),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('NanoTesla (nT) • Geofisika', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.analytics, size: 16),
                        ),
                      ],
                      selected: {_useMicroT},
                      onSelectionChanged: (val) {
                        setState(() => _useMicroT = val.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _useMicroT
                        ? 'Skala angka 40-70 µT (mudah dibaca, rekomendasi untuk pemula)'
                        : 'Skala angka 40.000-70.000 nT (satuan baku survei magnetik bumi profesional)',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Ambang Deteksi Anomali
          _buildSectionHeader('Ambang Batas Deteksi Anomali', theme),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Batas Anomali Tinggi (Logam/Kabel):', style: TextStyle(fontSize: 13)),
                      Text(
                        '${_highThresholdMicroT.toStringAsFixed(0)} µT',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                  Slider(
                    value: _highThresholdMicroT,
                    min: 50.0,
                    max: 80.0,
                    divisions: 30,
                    label: '${_highThresholdMicroT.toStringAsFixed(0)} µT',
                    onChanged: (val) => setState(() => _highThresholdMicroT = val),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Batas Anomali Sedang (Logam Ringan):', style: TextStyle(fontSize: 13)),
                      Text(
                        '${_mediumThresholdMicroT.toStringAsFixed(0)} µT',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                  Slider(
                    value: _mediumThresholdMicroT,
                    min: 44.0,
                    max: 55.0,
                    divisions: 22,
                    label: '${_mediumThresholdMicroT.toStringAsFixed(0)} µT',
                    onChanged: (val) => setState(() => _mediumThresholdMicroT = val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Manajemen Database & Penyimpanan
          _buildSectionHeader('Penyimpanan Data & Reset Pabrik', theme),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _isLoadingStats
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Proyek Survei', '$_surveyCount', theme),
                            _buildStatItem('Titik Stasiun', '$_stationCount', theme),
                            _buildStatItem('Sampel Sensor', '$_sampleCount', theme),
                          ],
                        ),
                  const Divider(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text(
                        'Reset Seluruh Data Aplikasi (Mulai dari Nol)',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _confirmFactoryReset,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Informasi Perangkat & Sensor
          _buildSectionHeader('Informasi Perangkat & Sensor', theme),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Aplikasi', 'GeoMag v1.0.0'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Tipe Sensor', _sensorInfo?.isUncalibrated == true ? 'Uncalibrated (Presisi Tinggi)' : 'Standar'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Chip Magnetometer', _sensorInfo?.name ?? 'Sensor Internal HP'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Resolusi Sensor', '${_sensorInfo?.resolutionMicroT?.toStringAsFixed(3) ?? "-"} µT'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Database Lokal', 'SQLite Drift (Encrypted/Offline)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
