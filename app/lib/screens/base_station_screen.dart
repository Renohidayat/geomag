import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../services/base_station_service.dart';
import '../services/magnetometer_service.dart';

/// Painter untuk visualisasi grafik time-series kurva variasi harian (drift curve).
class DriftCurvePainter extends CustomPainter {
  final List<BaseDriftPoint> points;
  final double? baselineFieldNt;

  const DriftCurvePainter({
    required this.points,
    this.baselineFieldNt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Background chart
    final bgPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), bgPaint);

    if (points.length < 2) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Menunggu aliran sampel base station...',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
      );
      return;
    }

    // Hitung min dan max delta
    var minDelta = double.infinity;
    var maxDelta = double.negativeInfinity;
    for (final p in points) {
      if (p.relativeDeltaNt < minDelta) minDelta = p.relativeDeltaNt;
      if (p.relativeDeltaNt > maxDelta) maxDelta = p.relativeDeltaNt;
    }

    // Beri margin minimal 5 nT
    if ((maxDelta - minDelta).abs() < 5.0) {
      final mid = (maxDelta + minDelta) / 2.0;
      minDelta = mid - 5.0;
      maxDelta = mid + 5.0;
    }

    final paddingV = 24.0;
    final paddingH = 16.0;
    final drawWidth = size.width - 2 * paddingH;
    final drawHeight = size.height - 2 * paddingV;

    // Garis baseline 0 nT
    final zeroY = paddingV + drawHeight * (1.0 - (0.0 - minDelta) / (maxDelta - minDelta));
    if (zeroY >= paddingV && zeroY <= size.height - paddingV) {
      final zeroPaint = Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(paddingH, zeroY),
        Offset(size.width - paddingH, zeroY),
        zeroPaint,
      );
    }

    // Gambar kurva polyline
    final linePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = paddingH + (i / (points.length - 1)) * drawWidth;
      final yNorm = (p.relativeDeltaNt - minDelta) / (maxDelta - minDelta);
      final y = paddingV + drawHeight * (1.0 - yNorm);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Titik terkini
    final lastPoint = points.last;
    final lastX = size.width - paddingH;
    final lastYNorm = (lastPoint.relativeDeltaNt - minDelta) / (maxDelta - minDelta);
    final lastY = paddingV + drawHeight * (1.0 - lastYNorm);

    final dotPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);

    // Label teks min, max, dan terkini
    final labelMax = TextPainter(
      text: TextSpan(
        text: '+${maxDelta.toStringAsFixed(1)} nT',
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelMax.paint(canvas, const Offset(8, 6));

    final labelMin = TextPainter(
      text: TextSpan(
        text: '${minDelta.toStringAsFixed(1)} nT',
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelMin.paint(canvas, Offset(8, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant DriftCurvePainter oldDelegate) => true;
}

/// Layar Mode Base Station untuk pemantauan variasi medan geomagnetik harian.
class BaseStationScreen extends StatefulWidget {
  final MagnetometerService? service;
  final AppDatabase? database;
  final BaseStationService? baseStationService;

  const BaseStationScreen({
    super.key,
    this.service,
    this.database,
    this.baseStationService,
  });

  @override
  State<BaseStationScreen> createState() => _BaseStationScreenState();
}

class _BaseStationScreenState extends State<BaseStationScreen> {
  late final MagnetometerService _magService;
  late final AppDatabase _database;
  late final BaseStationService _baseService;

  final TextEditingController _surveyNameController = TextEditingController(text: 'Base Station Harian');
  final TextEditingController _latController = TextEditingController(text: '-6.208800');
  final TextEditingController _lonController = TextEditingController(text: '106.845600');

  Timer? _uiRefreshTimer;
  Duration _elapsed = Duration.zero;
  String? _exportSuccessPath;

  @override
  void initState() {
    super.initState();
    _magService = widget.service ?? MagnetometerService();
    _database = widget.database ?? AppDatabase();
    _baseService = widget.baseStationService ??
        BaseStationService(
          database: _database,
          magnetometerService: _magService,
        );

    // Refresh UI setiap 500ms saat merekam
    _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_baseService.isRecording) {
        final start = _baseService.recordingStartTime;
        if (start != null) {
          setState(() {
            _elapsed = DateTime.now().difference(start);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _surveyNameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    if (widget.database == null) {
      _database.close();
    }
    super.dispose();
  }

  Future<void> _toggleBaseRecording() async {
    if (_baseService.isRecording) {
      // Hentikan perekaman
      await _baseService.stopBaseRecording();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Perekaman Base Station selesai (${_baseService.totalRecordedCount} sampel tersimpan)',
            ),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } else {
      // Inisialisasi Device & Survey Base
      const defaultDeviceId = 'default-device';
      await _database.insertDevice(
        const DevicesCompanion(
          id: Value(defaultDeviceId),
          model: Value('Base Station Device'),
          androidVersion: Value('Current'),
          magnetometerChip: Value('Magnetometer'),
        ),
      );

      final now = DateTime.now();
      final surveyId = 'base_${now.millisecondsSinceEpoch}';
      final stationId = 'st_base_${now.millisecondsSinceEpoch}';

      await _database.insertSurvey(
        SurveysCompanion.insert(
          id: surveyId,
          deviceId: defaultDeviceId,
          name: _surveyNameController.text.trim().isEmpty
              ? 'Base Station Harian'
              : _surveyNameController.text.trim(),
          date: now,
          mode: 'base',
          notes: const Value('Perekaman variasi harian base station'),
        ),
      );

      final lat = double.tryParse(_latController.text);
      final lon = double.tryParse(_lonController.text);

      await _database.insertStation(
        StationsCompanion.insert(
          id: stationId,
          surveyId: surveyId,
          sequenceNumber: 1,
          latitude: Value(lat),
          longitude: Value(lon),
          environmentNotes: const Value('Lokasi Base Station'),
        ),
      );

      await _baseService.startBaseRecording(
        surveyId: surveyId,
        stationId: stationId,
      );

      setState(() {
        _elapsed = Duration.zero;
        _exportSuccessPath = null;
      });
    }
  }

  Future<void> _exportCsv() async {
    try {
      final now = DateTime.now();
      final path = '${Directory.systemTemp.path}/geomag_base_${now.millisecondsSinceEpoch}.csv';
      final lat = double.tryParse(_latController.text);
      final lon = double.tryParse(_lonController.text);

      final file = await _baseService.exportBaseStationCsv(
        filePath: path,
        latitude: lat,
        longitude: lon,
      );

      setState(() {
        _exportSuccessPath = file.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File CSV diekspor ke: ${file.path}'),
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

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isRec = _baseService.isRecording;
    final points = _baseService.driftPoints;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Base Station'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Card
            Card(
              color: isRec ? Colors.red.shade900 : Colors.blueGrey.shade800,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isRec ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isRec ? Colors.redAccent : Colors.white60,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRec ? 'SEDANG MEREKAM BASE STATION' : 'BASE STATION STANDBY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            isRec
                                ? 'Durasi: ${_formatDuration(_elapsed)}'
                                : 'Tekan tombol di bawah untuk mulai sesi acuan harian',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Form Info Base
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _surveyNameController,
                      enabled: !isRec,
                      decoration: const InputDecoration(
                        labelText: 'Nama Survei Base Station',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            enabled: !isRec,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lonController,
                            enabled: !isRec,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Time-Series Chart
            const Text(
              'Kurva Variasi Harian (Drift Curve ΔB terhadap Waktu):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: CustomPaint(
                painter: DriftCurvePainter(
                  points: points,
                  baselineFieldNt: _baseService.baselineFieldNt,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Metrik Live Grid
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildMetricRow(
                      'Medan Rata-rata:',
                      '${_baseService.meanFieldNt.toStringAsFixed(1)} nT',
                    ),
                    _buildMetricRow(
                      'Baseline B₀:',
                      '${_baseService.baselineFieldNt?.toStringAsFixed(1) ?? "-"} nT',
                    ),
                    _buildMetricRow(
                      'Rentang Drift (Bmax - Bmin):',
                      '${_baseService.driftRangeNt.toStringAsFixed(1)} nT',
                    ),
                    _buildMetricRow(
                      'Simpangan Baku (σ):',
                      '${_baseService.stdDevFieldNt.toStringAsFixed(1)} nT',
                    ),
                    _buildMetricRow(
                      'Total Sampel Tersimpan:',
                      '${_baseService.totalRecordedCount} sampel',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Mulai / Hentikan
            ElevatedButton.icon(
              icon: Icon(isRec ? Icons.stop : Icons.play_arrow),
              label: Text(isRec ? 'Hentikan Perekaman Base Station' : 'Mulai Rekam Base Station'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: isRec ? Colors.red.shade700 : Colors.indigo,
                foregroundColor: Colors.white,
              ),
              onPressed: _toggleBaseRecording,
            ),

            // Tombol Ekspor CSV
            if (!isRec && _baseService.totalRecordedCount > 0) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download),
                label: const Text('Ekspor Dataset Base Station ke CSV'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _exportCsv,
              ),
            ],

            if (_exportSuccessPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Terekspor: $_exportSuccessPath',
                style: const TextStyle(fontSize: 11, color: Colors.green),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
