import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/magnetometer_sample.dart';
import '../services/ellipsoid_calibration_service.dart';
import '../services/magnetometer_service.dart';
import '../services/sphere_coverage_tracker.dart';

/// Painter visualisasi bola orientasi 3D dan sektor cakupan.
class SphereCoveragePainter extends CustomPainter {
  final SphereCoverageTracker tracker;
  final double? currentUx;
  final double? currentUy;
  final double? currentUz;

  const SphereCoveragePainter({
    required this.tracker,
    this.currentUx,
    this.currentUy,
    this.currentUz,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2.2;

    // Background bola
    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Border bola
    final borderPaint = Paint()
      ..color = Colors.blueGrey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, borderPaint);

    // Garis ekuator dan meridian
    final gridPaint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      gridPaint,
    );

    // Gambar elips meridian dan lintang
    final rect45 = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 1.414,
    );
    canvas.drawOval(rect45, gridPaint);

    // Gambar indikator sektor yang tercover
    for (final sector in tracker.sectors) {
      if (sector.isCovered) {
        // Tentukan posisi visual sektor pada proyeksi 2D
        final angle = (sector.minAzimuthRad + sector.maxAzimuthRad) / 2.0;
        final zenith = (sector.minZenithRad + sector.maxZenithRad) / 2.0;

        final rProj = radius * sin(zenith) * 0.85;
        final px = center.dx + rProj * cos(angle);
        final py = center.dy - rProj * sin(angle);

        final sectorPaint = Paint()
          ..color = Colors.tealAccent.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), 12, sectorPaint);

        final checkPaint = Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(px, py), 4, checkPaint);
      }
    }

    // Gambar pointer orientasi sensor saat ini
    final ux = currentUx;
    final uy = currentUy;
    final uz = currentUz;

    if (ux != null && uy != null && uz != null) {
      final px = center.dx + radius * ux * 0.9;
      final py = center.dy - radius * uy * 0.9;

      // Efek ukuran dan intensitas berdasarkan uz (arah depan vs belakang bola)
      final isFront = uz >= 0;
      final dotRadius = isFront ? 9.0 : 5.0;

      final pointerPaint = Paint()
        ..color = isFront ? Colors.amberAccent : Colors.amber.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;

      final glowPaint = Paint()
        ..color = (isFront ? Colors.amberAccent : Colors.amber).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(Offset(px, py), dotRadius + 4, glowPaint);
      canvas.drawCircle(Offset(px, py), dotRadius, pointerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SphereCoveragePainter oldDelegate) => true;
}

/// Layar panduan kalibrasi ellipsoid interaktif dengan bola orientasi 3D.
class CalibrationScreen extends StatefulWidget {
  final MagnetometerService? service;
  final AppDatabase? database;
  final EllipsoidCalibrationService? calibrationService;
  final int minSamples;
  final double bRefMicroT;

  const CalibrationScreen({
    super.key,
    this.service,
    this.database,
    this.calibrationService,
    this.minSamples = 200, // Default 200 untuk rotasi responsif
    this.bRefMicroT = 45.0, // Medan nominal standar (uT)
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  late final MagnetometerService _magService;
  late final AppDatabase _database;
  late final EllipsoidCalibrationService _calService;
  final SphereCoverageTracker _tracker = SphereCoverageTracker();

  StreamSubscription<MagnetometerSample>? _subscription;
  final List<List<double>> _recordedPoints = [];
  double _runningSumX = 0.0;
  double _runningSumY = 0.0;
  double _runningSumZ = 0.0;

  double? _currentUx;
  double? _currentUy;
  double? _currentUz;

  bool _isCalibrating = false;
  EllipsoidCalibrationResult? _calibrationResult;
  bool _isSaved = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _magService = widget.service ?? MagnetometerService();
    _database = widget.database ?? AppDatabase();
    _calService = widget.calibrationService ?? EllipsoidCalibrationService();
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (widget.database == null) {
      _database.close();
    }
    super.dispose();
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = _magService.sampleStream.listen((sample) {
      final x = sample.rawXMicroT;
      final y = sample.rawYMicroT;
      final z = sample.rawZMicroT;

      _recordedPoints.add([x, y, z]);
      _runningSumX += x;
      _runningSumY += y;
      _runningSumZ += z;

      // Estimasi pusat hard-iron dari OS atau running mean sampel
      double cx = sample.biasXMicroT;
      double cy = sample.biasYMicroT;
      double cz = sample.biasZMicroT;

      final n = _recordedPoints.length;
      if (cx == 0.0 && cy == 0.0 && cz == 0.0 && n >= 20) {
        cx = _runningSumX / n;
        cy = _runningSumY / n;
        cz = _runningSumZ / n;
      }

      final dx = x - cx;
      final dy = y - cy;
      final dz = z - cz;
      final norm = sqrt(dx * dx + dy * dy + dz * dz);

      if (norm > 1e-3) {
        _tracker.addSample(x, y, z, centerX: cx, centerY: cy, centerZ: cz);

        setState(() {
          _currentUx = dx / norm;
          _currentUy = dy / norm;
          _currentUz = dz / norm;
        });
      }
    });
  }

  void _resetCalibration() {
    setState(() {
      _recordedPoints.clear();
      _runningSumX = 0.0;
      _runningSumY = 0.0;
      _runningSumZ = 0.0;
      _tracker.reset();
      _calibrationResult = null;
      _isSaved = false;
      _errorMessage = null;
    });
  }

  Future<void> _runCalibration() async {
    if (_recordedPoints.length < 10) return;

    setState(() {
      _isCalibrating = true;
      _errorMessage = null;
    });

    try {
      final res = _calService.fitEllipsoidRobust(
        pointsMicroT: _recordedPoints,
        bRefMicroT: widget.bRefMicroT,
      );

      setState(() {
        _isCalibrating = false;
        _calibrationResult = res;
      });
    } catch (e) {
      setState(() {
        _isCalibrating = false;
        _errorMessage = 'Gagal menghitung kalibrasi: $e';
      });
    }
  }

  Future<void> _saveCalibration() async {
    final res = _calibrationResult;
    if (res == null) return;

    try {
      const deviceId = 'default-device';
      // Pastikan device record ada
      await _database.insertDevice(
        DevicesCompanion.insert(
          id: deviceId,
          model: 'Android Device',
          androidVersion: 'Current',
          magnetometerChip: 'Magnetometer',
        ),
      );

      await _calService.saveCalibrationProfile(
        database: _database,
        deviceId: deviceId,
        result: res,
      );

      setState(() => _isSaved = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profil kalibrasi berhasil disimpan (Residu: ${res.residualNt.toStringAsFixed(1)} nT)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal menyimpan profil kalibrasi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverage = _tracker.coveragePercentage;
    final coveredCount = _tracker.coveredSectorCount;
    final totalCount = _tracker.totalSectorCount;
    final sampleCount = _recordedPoints.length;
    final isReadyToCalibrate =
        coverage >= 45.0 && sampleCount >= widget.minSamples;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalibrasi Magnetometer'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Sampel',
            onPressed: _resetCalibration,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Panduan
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.screen_rotation_outlined,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Putar HP perlahan ke segala arah membentuk bola di udara hingga seluruh sektor terisi penuh.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Visualisasi Bola Orientasi
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: CustomPaint(
                  painter: SphereCoveragePainter(
                    tracker: _tracker,
                    currentUx: _currentUx,
                    currentUy: _currentUy,
                    currentUz: _currentUz,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status Cakupan dan Progress
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cakupan Orientasi 3D:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${coverage.toStringAsFixed(1)}% ($coveredCount/$totalCount sektor)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: coverage >= 70.0
                                ? Colors.green
                                : (coverage >= 40.0
                                    ? Colors.orange
                                    : Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: coverage / 100.0,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        coverage >= 70.0 ? Colors.green : Colors.orange,
                      ),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jumlah Titik Sampel:'),
                        Text(
                          '$sampleCount / ${widget.minSamples}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),

            // Tombol Hitung Kalibrasi
            ElevatedButton.icon(
              icon: _isCalibrating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate_outlined),
              label: Text(
                _isCalibrating
                    ? 'Menghitung Kalibrasi...'
                    : (isReadyToCalibrate
                        ? 'Hitung Kalibrasi Ellipsoid'
                        : 'Sampel / Cakupan Belum Cukup'),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor:
                    isReadyToCalibrate ? Colors.indigo : Colors.grey.shade400,
                foregroundColor: Colors.white,
              ),
              onPressed:
                  (_isCalibrating || !isReadyToCalibrate) ? null : _runCalibration,
            ),

            // Hasil Kalibrasi
            if (_calibrationResult != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.teal.shade50,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.teal.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hasil Kalibrasi Ellipsoid',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const Divider(),
                      _buildMetricRow(
                        'Residu Kalibrasi (RMSE):',
                        '${_calibrationResult!.residualNt.toStringAsFixed(1)} nT',
                      ),
                      _buildMetricRow(
                        'Simpangan Baku Sebelum:',
                        '${_calibrationResult!.stdBeforeNt.toStringAsFixed(1)} nT',
                      ),
                      _buildMetricRow(
                        'Simpangan Baku Sesudah:',
                        '${_calibrationResult!.stdAfterNt.toStringAsFixed(1)} nT',
                      ),
                      _buildMetricRow(
                        'Hard Iron Offset b:',
                        '[${_calibrationResult!.offsetMicroT.map((v) => v.toStringAsFixed(1)).join(', ')}] µT',
                      ),
                      _buildMetricRow(
                        'Inlier Digunakan:',
                        '${_calibrationResult!.inlierCount} titik',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(
                            _isSaved ? Icons.check : Icons.save_outlined,
                          ),
                          label: Text(
                            _isSaved
                                ? 'Tersimpan di Profil HP ✓'
                                : 'Simpan Profil Kalibrasi ke Database',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isSaved ? Colors.green : Colors.teal.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isSaved ? null : _saveCalibration,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
