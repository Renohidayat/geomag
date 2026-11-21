import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../models/magnetometer_sample.dart';
import '../models/sensor_info.dart';
import '../services/ellipsoid_calibration_service.dart';
import '../services/magnetometer_service.dart';
import '../services/recording_session_service.dart';
import '../widgets/analog_gauge_widget.dart';
import '../widgets/live_waveform_chart.dart';
import 'anomaly_map_screen.dart';
import 'base_station_screen.dart';
import 'calibration_screen.dart';
import 'noise_test_screen.dart';
import 'station_survey_screen.dart';
import 'survey_quality_report_screen.dart';
import 'room_thermometer_screen.dart';
import 'settings_screen.dart';

/// Layar utama: menampilkan data magnetometer real-time dan metrik instrumen
/// dengan antarmuka ramah pengguna (meteran jarum analog & grafik gelombang).
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
  EllipsoidCalibrationResult? _activeCalibration;
  StreamSubscription<MagnetometerSample>? _subscription;
  bool _isRecording = false;
  String? _errorMessage;
  String? _exportedFilePath;
  DateTime? _recordingStartTime;
  Timer? _durationTimer;
  Duration _recordingDuration = Duration.zero;

  // Riwayat data gelombang untuk grafik real-time bergulir ala Phyphox
  final List<double> _waveformHistory = [];

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
    _loadActiveCalibration();
  }

  Future<void> _loadActiveCalibration() async {
    try {
      final profile = await _database.getLatestCalibrationProfile('default-device');
      if (profile != null && mounted) {
        final elements = profile.matrixA.split(',').map((s) => double.parse(s.trim())).toList();
        setState(() {
          _activeCalibration = EllipsoidCalibrationResult(
            offsetMicroT: [
              profile.hardIronBxMicroT,
              profile.hardIronByMicroT,
              profile.hardIronBzMicroT,
            ],
            matrixA: elements,
            residualNt: profile.residualNt,
            stdBeforeNt: 0.0,
            stdAfterNt: 0.0,
            inlierCount: 0,
          );
        });
      }
    } catch (_) {
      // Abaikan jika belum ada profil kalibrasi
    }
  }

  double _calculateCalibratedNt(MagnetometerSample sample) {
    if (_activeCalibration != null) {
      return _activeCalibration!.calibratedTotalFieldNt(
        sample.rawXMicroT,
        sample.rawYMicroT,
        sample.rawZMicroT,
      );
    }
    return sample.calibratedTotalFieldNt;
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
    _waveformHistory.clear();
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
        final currentNt = _calculateCalibratedNt(sample);
        final currentMicroT = currentNt / 1000.0;
        _sumTotalFieldMicroT += currentMicroT;
        _sumTotalFieldSqMicroT += currentMicroT * currentMicroT;

        _waveformHistory.add(currentNt);
        if (_waveformHistory.length > 80) {
          _waveformHistory.removeAt(0);
        }

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
    return variance > 0.0 ? (variance > 1e-12 ? _sqrt(variance) : 0.0) : 0.0;
  }

  double _sqrt(double v) {
    if (v <= 0.0) return 0.0;
    var x = v;
    for (var i = 0; i < 15; i++) {
      x = 0.5 * (x + v / x);
    }
    return x;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentFieldNt = _lastSample != null ? _calculateCalibratedNt(_lastSample!) : 45000.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoMag - Survei Magnetik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Survei Stasiun (Rover)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StationSurveyScreen(
                    service: _magnetometerService,
                    database: _database,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.screen_rotation_outlined),
            tooltip: 'Kalibrasi Magnetometer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CalibrationScreen(
                    service: _magnetometerService,
                    database: _database,
                  ),
                ),
              ).then((_) => _loadActiveCalibration());
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Uji Lantai Noise',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NoiseTestScreen(
                    service: _magnetometerService,
                    database: _database,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Peta Anomali 2D',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnomalyMapScreen(
                    database: _database,
                    service: _magnetometerService,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Laporan Mutu Survei',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SurveyQualityReportScreen(
                    database: _database,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan & Reset Data',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    database: _database,
                    service: _magnetometerService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Meteran Jarum Analog Visual (Speedometer ala Ultimate EMF Detector)
            AnalogGaugeWidget(valueNt: currentFieldNt),
            const SizedBox(height: 12),

            // 2. Grafik Gelombang Real-Time yang Bergulir Dinamis (ala Phyphox)
            if (_waveformHistory.isNotEmpty) ...[
              LiveWaveformChart(historyNt: _waveformHistory),
              const SizedBox(height: 12),
            ],

            // Pesan Error jika terjadi kendala
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

            // Feedback Ekspor CSV
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

            // 3. Menu Navigasi Dashboard Utama yang Ramah Pengguna
            _buildDashboardNavigation(theme),
            const SizedBox(height: 16),

            // 4. Data Sumbu Tiga Dimensi & Statistik Saat Streaming Aktif
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
              const SizedBox(height: 12),
            ],

            // 5. Kartu Info Sensor HP
            _buildSensorInfoCard(theme),
            const SizedBox(height: 60), // Padding bawah agar tidak tertutup tombol FAB
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

  /// Dashboard kartu navigasi utama dengan bahasa Indonesia yang jelas, formal, dan ramah pemula.
  Widget _buildDashboardNavigation(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            'Fitur Utama Aplikasi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Menu 1: Peta Sebaran Batuan 2D (Paling Penting & Keren)
        _buildNavCard(
          theme: theme,
          title: 'Peta Sebaran Batuan 2D',
          subtitle: 'Melihat peta kontur warna sebaran anomali batuan & logam di bawah tanah',
          icon: Icons.map,
          color: Colors.blueAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnomalyMapScreen(
                  database: _database,
                  service: _magnetometerService,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Menu 2: Survei Titik Lapangan (Mode Rover)
        _buildNavCard(
          theme: theme,
          title: 'Survei Titik Lapangan (Mode Rover)',
          subtitle: 'Merekam data medan magnetik di patok-patok survei secara bertahap',
          icon: Icons.location_on,
          color: Colors.teal,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StationSurveyScreen(
                  service: _magnetometerService,
                  database: _database,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Menu 3: Kalibrasi Sensor HP
        _buildNavCard(
          theme: theme,
          title: 'Kalibrasi Sensor Magnetik',
          subtitle: 'Gerakkan HP membentuk angka 8 untuk menetralkan medan magnet baterai HP',
          icon: Icons.screen_rotation,
          color: Colors.deepPurpleAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CalibrationScreen(
                  service: _magnetometerService,
                  database: _database,
                ),
              ),
            ).then((_) => _loadActiveCalibration());
          },
        ),
        const SizedBox(height: 8),

        // Menu 4: Uji Kestabilan Sensor (Noise)
        _buildNavCard(
          theme: theme,
          title: 'Uji Kestabilan Sensor (Noise Floor)',
          subtitle: 'Memeriksa ketenangan sensor HP agar hasil survei dapat diandalkan',
          icon: Icons.analytics,
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoiseTestScreen(
                  service: _magnetometerService,
                  database: _database,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Menu 5: Laporan Mutu Survei
        _buildNavCard(
          theme: theme,
          title: 'Laporan Mutu Data Survei',
          subtitle: 'Audit resmi kualitas pengukuran dengan penilaian Grade A/B/C/D',
          icon: Icons.fact_check,
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SurveyQualityReportScreen(database: _database),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Menu 6: Stasiun Pangkalan (Base Station)
        _buildNavCard(
          theme: theme,
          title: 'Perekaman Stasiun Pangkalan (Base Station)',
          subtitle: 'Merekam variasi harian medan magnet bumi secara otomatis dan kontinu',
          icon: Icons.radar,
          color: Colors.indigo,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BaseStationScreen(
                  service: _magnetometerService,
                  database: _database,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Menu 7: Termometer Suhu Sekitar & Cuaca (Digital Thermometer)
        _buildNavCard(
          theme: theme,
          title: 'Termometer Suhu Sekitar & Cuaca',
          subtitle: 'Pendeteksi hawa suhu sekitar (panas/dingin), kelembaban, tekanan barometer, & cuaca wilayah',
          icon: Icons.device_thermostat,
          color: Colors.deepOrangeAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RoomThermometerScreen(
                  service: _magnetometerService,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Menu 8: Pengaturan Aplikasi & Manajemen Data
        _buildNavCard(
          theme: theme,
          title: 'Pengaturan & Manajemen Data',
          subtitle: 'Ubah preferensi satuan, ambang deteksi, dan reset data pabrik',
          icon: Icons.settings,
          color: Colors.blueGrey,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(
                  database: _database,
                  service: _magnetometerService,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNavCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
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
    final currentNt = _calculateCalibratedNt(s);
    final currentMicroT = currentNt / 1000.0;
    final isCalibrated = _activeCalibration != null || s.biasXMicroT != 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Data Medan Magnetik (Real-time)',
                    style: theme.textTheme.titleSmall),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCalibrated
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _activeCalibration != null
                        ? 'Ellipsoid Aktif ✓'
                        : (s.biasXMicroT != 0.0 ? 'Auto-Bias Aktif ✓' : 'Medan Mentah'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isCalibrated ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            _infoRow('Bx (komponen X)', '${s.calibratedXMicroT.toStringAsFixed(2)} µT'),
            _infoRow('By (komponen Y)', '${s.calibratedYMicroT.toStringAsFixed(2)} µT'),
            _infoRow('Bz (komponen Z)', '${s.calibratedZMicroT.toStringAsFixed(2)} µT'),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Medan Total (F)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${currentNt.toStringAsFixed(0)} nT  '
                  '(${currentMicroT.toStringAsFixed(2)} µT)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final mean = _displaySampleCount > 0
        ? _sumTotalFieldMicroT / _displaySampleCount
        : 0.0;
    final stdDev = _stdDevMicroT;
    final stdDevNt = stdDev * 1000.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistik Perekaman', style: theme.textTheme.titleSmall),
            const Divider(),
            _infoRow('Jumlah sampel', '$_displaySampleCount'),
            _infoRow(
              'Rata-rata total field',
              '${mean.toStringAsFixed(2)} µT  '
              '(${(mean * 1000).toStringAsFixed(0)} nT)',
            ),
            _infoRow(
              'Simpangan baku (σ)',
              '${stdDev.toStringAsFixed(3)} µT  '
              '(${stdDevNt.toStringAsFixed(1)} nT)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard(ThemeData theme) {
    final s = _lastSample!;
    final temp = s.batteryTempC;
    final isCharging = s.isCharging;
    final isScreenOn = s.isScreenOn;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status Perangkat', style: theme.textTheme.titleSmall),
            const Divider(),
            _infoRow(
              'Akurasi sensor',
              _accuracyLabel(s.accuracy),
            ),
            _infoRow(
              'Suhu baterai',
              '${temp.toStringAsFixed(1)} °C',
            ),
            _infoRow(
              'Sumber daya',
              isCharging == true
                  ? 'Pengisian daya (PERINGATAN: dapat memicu noise)'
                  : 'Baterai (Aman ✓)',
            ),
            _infoRow(
              'Layar',
              isScreenOn == true ? 'Menyala' : 'Mati / Redup',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _accuracyLabel(int accuracy) {
    switch (accuracy) {
      case 0:
        return 'Tidak dapat diandalkan (0)';
      case 1:
        return 'Rendah (1)';
      case 2:
        return 'Sedang (2)';
      case 3:
        return 'Tinggi (3)';
      default:
        return 'Tidak diketahui ($accuracy)';
    }
  }
}
