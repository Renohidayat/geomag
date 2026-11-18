import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/magnetometer_sample.dart';
import '../services/ellipsoid_calibration_service.dart';
import '../services/magnetometer_service.dart';
import '../services/nmea_parser_service.dart';
import '../services/station_aggregation_service.dart';

/// Layar survei stasiun rover: perekaman diam, evaluasi mutu statistik, dan penyimpanan ke database.
class StationSurveyScreen extends StatefulWidget {
  final MagnetometerService? service;
  final AppDatabase? database;
  final StationAggregationService? aggregationService;
  final NmeaParserService? nmeaParser;
  final int recordDurationSeconds;
  final double maxStdDevNt;
  final int minSamples;

  const StationSurveyScreen({
    super.key,
    this.service,
    this.database,
    this.aggregationService,
    this.nmeaParser,
    this.recordDurationSeconds = 5, // Default 5 detik agar ramah awam
    this.maxStdDevNt = 1000.0,
    this.minSamples = 50,
  });

  @override
  State<StationSurveyScreen> createState() => _StationSurveyScreenState();
}

class _StationSurveyScreenState extends State<StationSurveyScreen> {
  late final MagnetometerService _magService;
  late final AppDatabase _database;
  late final StationAggregationService _aggregationService;
  late final NmeaParserService _nmeaParser;

  StreamSubscription<MagnetometerSample>? _subscription;
  Timer? _countdownTimer;

  String? _activeSurveyId;
  final String _activeSurveyName = 'Survei Lapangan Utama';
  int _nextStationSequence = 1;

  final TextEditingController _surveyNameController = TextEditingController();
  final TextEditingController _latController = TextEditingController(text: '-6.208800');
  final TextEditingController _lonController = TextEditingController(text: '106.845600');
  final TextEditingController _altController = TextEditingController(text: '25.0');

  bool _useExternalGnss = false;
  NmeaPosition? _externalGnssPosition;

  int _selectedDurationSeconds = 5;
  bool _showTechnicalDetails = false;
  EllipsoidCalibrationResult? _activeCalibration;

  bool _isRecording = false;
  int _remainingSeconds = 0;
  final List<MagnetometerSample> _stationSamples = [];

  StationAggregationResult? _aggregationResult;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _magService = widget.service ?? MagnetometerService();
    _database = widget.database ?? AppDatabase();
    _nmeaParser = widget.nmeaParser ?? const NmeaParserService();
    _aggregationService = widget.aggregationService ??
        StationAggregationService(
          maxStdDevNt: widget.maxStdDevNt,
          minSamples: widget.minSamples,
        );

    _selectedDurationSeconds = widget.recordDurationSeconds;
    _initSurvey();
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
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _subscription?.cancel();
    _surveyNameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _altController.dispose();
    if (widget.database == null) {
      _database.close();
    }
    super.dispose();
  }

  Future<void> _initSurvey() async {
    const defaultDeviceId = 'default-device';
    // Pastikan device ada
    await _database.insertDevice(
      const DevicesCompanion(
        id: Value(defaultDeviceId),
        model: Value('Android Device'),
        androidVersion: Value('Current'),
        magnetometerChip: Value('Magnetometer'),
      ),
    );

    const defaultSurveyId = 'survey_default_rover';
    final existing = await (_database.select(_database.surveys)
          ..where((tbl) => tbl.id.equals(defaultSurveyId)))
        .getSingleOrNull();

    if (existing == null) {
      final now = DateTime.now();
      await _database.insertSurvey(
        SurveysCompanion.insert(
          id: defaultSurveyId,
          deviceId: defaultDeviceId,
          name: _activeSurveyName,
          date: now,
          mode: 'rover',
          notes: const Value('Survei rover lapangan GeoMag'),
        ),
      );
    }

    // Ambil stasiun terakhir untuk auto-increment sequenceNumber
    final lastStations = await (_database.select(_database.stations)
          ..where((tbl) => tbl.surveyId.equals(defaultSurveyId))
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.sequenceNumber,
                  mode: OrderingMode.desc,
                )
          ])
          ..limit(1))
        .get();

    final nextSeq = lastStations.isNotEmpty
        ? lastStations.first.sequenceNumber + 1
        : 1;

    setState(() {
      _activeSurveyId = defaultSurveyId;
      _nextStationSequence = nextSeq;
    });
  }

  void _startStationRecording() {
    setState(() {
      _isRecording = true;
      _isSaved = false;
      _aggregationResult = null;
      _stationSamples.clear();
      _remainingSeconds = _selectedDurationSeconds;
    });

    _subscription?.cancel();
    _subscription = _magService.sampleStream.listen((sample) {
      _stationSamples.add(sample);
      setState(() {});
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _finishStationRecording();
      }
    });
  }

  void _finishStationRecording() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _subscription?.cancel();
    _subscription = null;

    final thresholdMinSamples = widget.minSamples != 100
        ? widget.minSamples
        : (_selectedDurationSeconds <= 5 ? 50 : 100);

    final result = _aggregationService.aggregateStationSamples(
      samples: _stationSamples,
      calibrationProfile: _activeCalibration,
      customMinSamples: thresholdMinSamples,
    );

    setState(() {
      _isRecording = false;
      _aggregationResult = result;
    });
  }

  Future<void> _saveStationToDatabase() async {
    final res = _aggregationResult;
    final surveyId = _activeSurveyId;
    if (res == null || surveyId == null) return;

    try {
      final stationId = 'st_${surveyId}_$_nextStationSequence';
      final lat = double.tryParse(_latController.text);
      final lon = double.tryParse(_lonController.text);

      // 1. Simpan Station
      await _database.insertStation(
        StationsCompanion.insert(
          id: stationId,
          surveyId: surveyId,
          sequenceNumber: _nextStationSequence,
          latitude: Value(lat),
          longitude: Value(lon),
          environmentNotes: Value('Status: ${res.qualityFlag} - ${res.statusReason}'),
        ),
      );

      // 2. Simpan StationResults
      await _database.saveStationResult(
        StationResultsCompanion.insert(
          id: 'res_$stationId',
          stationId: stationId,
          totalFieldMeanNt: res.meanTotalFieldNt,
          totalFieldStdNt: res.stdDevTotalFieldNt,
          sampleCount: res.sampleCount,
          isAccepted: res.isAccepted,
          rejectionReason: res.isAccepted ? const Value.absent() : Value(res.statusReason),
        ),
      );

      // 3. Batch simpan sampel mentah (Samples)
      final sampleCompanions = _stationSamples.asMap().entries.map((entry) {
        final idx = entry.key;
        final s = entry.value;
        return SamplesCompanion.insert(
          id: '${stationId}_${s.timestampNs}_$idx',
          stationId: stationId,
          timestampNs: BigInt.from(s.timestampNs),
          rawXMicroT: s.rawXMicroT,
          rawYMicroT: s.rawYMicroT,
          rawZMicroT: s.rawZMicroT,
          biasXMicroT: s.biasXMicroT,
          biasYMicroT: s.biasYMicroT,
          biasZMicroT: s.biasZMicroT,
          accuracy: s.accuracy,
          isUncalibrated: s.isUncalibrated,
          batteryTempC: s.batteryTempC,
          isCharging: s.isCharging,
          isScreenOn: s.isScreenOn,
        );
      }).toList();

      await _database.insertSamplesBatch(sampleCompanions);

      setState(() {
        _isSaved = true;
        _nextStationSequence++;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stasiun #$_nextStationSequence berhasil disimpan (${res.meanTotalFieldNt.toStringAsFixed(1)} ± ${res.stdDevTotalFieldNt.toStringAsFixed(1)} nT)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan stasiun ke database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyNmeaSentence(String sentence) {
    final pos = _nmeaParser.parseSentence(sentence);
    if (pos != null) {
      setState(() {
        _externalGnssPosition = pos;
        _latController.text = pos.latitude.toStringAsFixed(6);
        _lonController.text = pos.longitude.toStringAsFixed(6);
        if (pos.altitudeM != null) {
          _altController.text = pos.altitudeM!.toStringAsFixed(1);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Posisi GNSS diperbarui: ${pos.fixQuality.label} (HDOP: ${pos.hdop ?? "-"})'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kalimat NMEA tidak valid atau checksum salah!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNmeaInputDialog() {
    final textController = TextEditingController(
      text:
          '\$GNGGA,072412.00,0653.4800,S,10736.7200,E,4,18,0.65,765.20,M,25.4,M,1.2,0001*41',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth, color: Colors.blue),
            SizedBox(width: 8),
            Text('Input Stream NMEA GNSS', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan atau tempel kalimat NMEA (GGA / RMC) dari receiver GNSS eksternal Bluetooth (DGPS / RTK):',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '\$GNGGA,123456...*CS',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                _applyNmeaSentence(text);
              }
            },
            child: const Text('Terapkan Koordinat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = _aggregationResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Survei Stasiun Rover'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Info Survei & Stasiun
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _activeSurveyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Stasiun #$_nextStationSequence',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const Text(
                      'Sumber Posisi:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('GPS HP Internal', style: TextStyle(fontSize: 11)),
                            icon: Icon(Icons.smartphone, size: 14),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('NMEA Eksternal', style: TextStyle(fontSize: 11)),
                            icon: Icon(Icons.bluetooth, size: 14),
                          ),
                        ],
                        selected: {_useExternalGnss},
                        onSelectionChanged: (val) {
                          setState(() => _useExternalGnss = val.first);
                        },
                      ),
                    ),
                    if (_useExternalGnss) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _externalGnssPosition != null
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _externalGnssPosition != null
                                ? Colors.green.shade400
                                : Colors.orange.shade400,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _externalGnssPosition != null
                                  ? Icons.gps_fixed
                                  : Icons.gps_not_fixed,
                              size: 20,
                              color: _externalGnssPosition != null
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _externalGnssPosition != null
                                        ? 'Fix: ${_externalGnssPosition!.fixQuality.label} (Sat: ${_externalGnssPosition!.satellites ?? "-"}, HDOP: ${_externalGnssPosition!.hdop ?? "-"})'
                                        : 'Belum ada kalimat NMEA terhubung',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  if (_externalGnssPosition != null)
                                    Text(
                                      'Alt: ${_externalGnssPosition!.altitudeM?.toStringAsFixed(1) ?? "-"}m • Tipe: ${_externalGnssPosition!.sentenceType}',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.input, size: 16),
                              label: const Text('Input NMEA', style: TextStyle(fontSize: 11)),
                              onPressed: _showNmeaInputDialog,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Koordinat Lokasi Stasiun:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
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
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _altController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Elev (m)',
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

            // Card Perekaman Diam Real-Time
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRecording ? Icons.hourglass_top_rounded : Icons.pan_tool_alt_outlined,
                          color: _isRecording ? Colors.indigo : Colors.teal.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRecording
                              ? 'Merekam... Tahan HP Diam! ($_remainingSeconds s)'
                              : 'Pegang HP Diam & Tenang di Titik Ini',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isRecording ? Colors.indigo : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isRecording) ...[
                      LinearProgressIndicator(
                        value: (_selectedDurationSeconds - _remainingSeconds) /
                            _selectedDurationSeconds,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      // Pilihan Durasi Pengukuran
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Waktu Uji:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('5 Detik (Cepat)', style: TextStyle(fontSize: 11)),
                            selected: _selectedDurationSeconds == 5,
                            onSelected: (sel) {
                              if (sel) setState(() => _selectedDurationSeconds = 5);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('10 Detik', style: TextStyle(fontSize: 11)),
                            selected: _selectedDurationSeconds == 10,
                            onSelected: (sel) {
                              if (sel) setState(() => _selectedDurationSeconds = 10);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('30 Detik', style: TextStyle(fontSize: 11)),
                            selected: _selectedDurationSeconds == 30,
                            onSelected: (sel) {
                              if (sel) setState(() => _selectedDurationSeconds = 30);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox(
                          'Sampel Terkumpul',
                          '${_stationSamples.length}',
                          Icons.data_usage,
                        ),
                        _buildStatBox(
                          'Target Waktu',
                          '${_selectedDurationSeconds}s',
                          Icons.timer_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Mulai Rekam Stasiun
            ElevatedButton.icon(
              icon: Icon(_isRecording ? Icons.hourglass_top : Icons.play_arrow),
              label: Text(
                _isRecording
                    ? 'Sedang Merekam... Mohon Tahan Diam ($_remainingSeconds s)'
                    : 'Mulai Rekam Titik Stasiun ($_selectedDurationSeconds Detik)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isRecording ? Colors.grey : Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isRecording ? null : _startStationRecording,
            ),
            const SizedBox(height: 16),

            // Banner Hasil Evaluasi Mutu
            if (res != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: res.isAccepted ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: res.isAccepted ? Colors.green.shade400 : Colors.red.shade300,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          res.isAccepted ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: res.isAccepted ? Colors.green.shade700 : Colors.red.shade700,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            res.isAccepted
                                ? '✓ Titik Stasiun Berhasil Direkam!'
                                : '⚠️ HP Tadi Agak Bergoyang',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: res.isAccepted ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      res.isAccepted
                          ? 'Posisi HP tenang dan hasil pengukuran medan magnetik stabil.'
                          : 'Sensor mendeteksi HP bergerak saat merekam. Mohon tahan HP tetap diam dan tenang selama $_selectedDurationSeconds detik ya.',
                      style: TextStyle(
                        fontSize: 13,
                        color: res.isAccepted ? Colors.green.shade900 : Colors.red.shade900,
                        height: 1.4,
                      ),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kekuatan Medan Magnet:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          '${res.meanTotalFieldNt.toStringAsFixed(0)} nT',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Data Terkumpul:', style: TextStyle(color: Colors.grey)),
                        Text('${res.sampleCount} sampel ($_selectedDurationSeconds detik)'),
                      ],
                    ),

                    // Rincian Teknis Geofisika (Expandable / Toggle)
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        setState(() => _showTechnicalDetails = !_showTechnicalDetails);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _showTechnicalDetails ? 'Sembunyikan Rincian Teknis ▲' : 'Lihat Rincian Teknis Geofisika ▼',
                              style: TextStyle(fontSize: 12, color: Colors.indigo.shade700, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showTechnicalDetails) ...[
                      const Divider(height: 16),
                      _buildResultRow('Simpangan Baku (σ):', '${res.stdDevTotalFieldNt.toStringAsFixed(1)} nT (Batas < 1000 nT)'),
                      _buildResultRow('Median Medan Total:', '${res.medianTotalFieldNt.toStringAsFixed(1)} nT'),
                      _buildResultRow('Status Asli:', '${res.qualityFlag} (${res.statusReason})'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tombol Simpan / Ulangi
              if (res.isAccepted)
                ElevatedButton.icon(
                  icon: Icon(_isSaved ? Icons.check : Icons.save),
                  label: Text(
                    _isSaved
                        ? 'Tersimpan ✓ (Lanjut ke Stasiun Berikutnya)'
                        : 'Simpan Titik Stasiun #$_nextStationSequence ke Database',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _isSaved ? Colors.grey : Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaved ? null : _saveStationToDatabase,
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'Ulangi Rekam Titik (Tahan HP Diam)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepOrange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _startStationRecording,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueGrey),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
