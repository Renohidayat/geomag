import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/magnetometer_sample.dart';
import '../services/analytic_signal_service.dart';
import '../services/gridding_service.dart';
import '../services/magnetometer_service.dart';
import '../services/qgis_export_service.dart';
import '../services/rtp_service.dart';

/// Jenis layer visualisasi pada peta anomali magnetik.
enum MapLayerType {
  /// Medan total hasil observasi / terkoreksi ($B_{obs}$) dalam nT.
  totalField,

  /// Anomali medan magnetik total ($\Delta T = B_{obs} - B_{diurnal} - F_{IGRF}$) dalam nT.
  deltaT,

  /// Magnitudo sinyal analitik 3D ($|AS| = \sqrt{Tx^2 + Ty^2 + Tz^2}$) dalam nT/m.
  analyticSignal,

  /// Reduction to Pole (RTP) teratur untuk lintang rendah dalam nT.
  rtp,
}

/// Data ringkasan stasiun untuk overlay pada peta.
class MapStationMarker {
  final String stationId;
  final int sequenceNumber;
  final double x;
  final double y;
  final double? latitude;
  final double? longitude;
  final double totalFieldNt;
  final double? diurnalCorrectionNt;
  final double? fIgrfNt;
  final double? deltaTNt;
  final bool isAccepted;
  final String qualityFlag;

  const MapStationMarker({
    required this.stationId,
    required this.sequenceNumber,
    required this.x,
    required this.y,
    this.latitude,
    this.longitude,
    required this.totalFieldNt,
    this.diurnalCorrectionNt,
    this.fIgrfNt,
    this.deltaTNt,
    required this.isAccepted,
    required this.qualityFlag,
  });
}

/// Layar visualisasi peta anomali 2D interaktif dengan grid colormap dan overlay stasiun.
class AnomalyMapScreen extends StatefulWidget {
  final AppDatabase database;
  final MagnetometerService? service;
  final GriddingService griddingService;
  final AnalyticSignalService analyticSignalService;
  final QgisExportService exportService;
  final RtpService rtpService;

  const AnomalyMapScreen({
    super.key,
    required this.database,
    this.service,
    this.griddingService = const GriddingService(),
    this.analyticSignalService = const AnalyticSignalService(),
    this.exportService = const QgisExportService(),
    this.rtpService = const RtpService(),
  });

  @override
  State<AnomalyMapScreen> createState() => _AnomalyMapScreenState();
}

class _AnomalyMapScreenState extends State<AnomalyMapScreen> {
  final TransformationController _transformController =
      TransformationController();

  MapLayerType _selectedLayer = MapLayerType.deltaT;
  List<Survey> _surveys = [];
  Map<String, int> _surveyStationCounts = {};
  String? _selectedSurveyId;
  bool _isLoading = true;
  String? _statusMessage;

  List<MapStationMarker> _stations = [];
  Grid2D? _totalFieldGrid;
  Grid2D? _deltaTGrid;
  Grid2D? _rtpGrid;
  AnalyticSignalResult? _asResult;

  MapStationMarker? _highlightedStation;

  // Fitur ramah pengguna: Orientasi jalur, nomor titik, dan live sensor monitor
  StreamSubscription<MagnetometerSample>? _sensorSubscription;
  double? _liveTotalFieldMicroT;
  double? _liveTotalFieldNt;
  bool _showPath = true;
  bool _showStationNumbers = true;
  bool _showLiveMonitor = true;

  @override
  void initState() {
    super.initState();
    _initLiveSensor();
    _loadSurveys();
  }

  void _initLiveSensor() {
    final s = widget.service;
    if (s != null) {
      try {
        _sensorSubscription = s.sampleStream.listen(
          (sample) {
            if (!mounted) return;
            setState(() {
              _liveTotalFieldMicroT = sample.calibratedTotalFieldMicroT;
              _liveTotalFieldNt = sample.calibratedTotalFieldNt;
            });
          },
          onError: (_) {},
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadSurveys() async {
    setState(() => _isLoading = true);
    try {
      final allSurveys = await widget.database.select(widget.database.surveys).get();
      final roverSurveys = allSurveys.where((s) => s.mode == 'rover').toList();

      final counts = <String, int>{};
      for (final s in roverSurveys) {
        final stList = await (widget.database.select(widget.database.stations)
              ..where((tbl) => tbl.surveyId.equals(s.id)))
            .get();
        counts[s.id] = stList.length;
      }

      // Urutkan: Survei Lapangan Utama di atas, lalu berdasarkan jumlah stasiun terbanyak
      roverSurveys.sort((a, b) {
        if (a.id == 'survey_default_rover') return -1;
        if (b.id == 'survey_default_rover') return 1;
        final countA = counts[a.id] ?? 0;
        final countB = counts[b.id] ?? 0;
        if (countA != countB) return countB.compareTo(countA);
        return b.date.compareTo(a.date);
      });

      if (mounted) {
        setState(() {
          _surveys = roverSurveys;
          _surveyStationCounts = counts;
          if (roverSurveys.isNotEmpty) {
            _selectedSurveyId = roverSurveys.first.id;
          }
        });
      }

      if (_selectedSurveyId != null) {
        await _loadSurveyData(_selectedSurveyId!);
      } else {
        _generateDemoData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Gagal memuat survei: $e';
          _generateDemoData();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSurveyData(String surveyId) async {
    setState(() => _isLoading = true);
    try {
      final db = widget.database;
      final stList = await (db.select(db.stations)
            ..where((tbl) => tbl.surveyId.equals(surveyId)))
          .get();

      if (stList.isEmpty) {
        _generateDemoData();
        return;
      }

      final stResults = await db.select(db.stationResults).get();
      final resultMap = {for (final r in stResults) r.stationId: r};

      final anomalies = await db.select(db.anomalies).get();
      final anomMap = {for (final a in anomalies) a.stationId: a};

      final markers = <MapStationMarker>[];
      for (final st in stList) {
        final res = resultMap[st.id];
        final anom = anomMap[st.id];

        final x = st.localX ?? (st.longitude != null ? st.longitude! * 111320.0 : st.sequenceNumber * 10.0);
        final y = st.localY ?? (st.latitude != null ? st.latitude! * 110540.0 : 0.0);
        final tf = res?.totalFieldMeanNt ?? 45000.0;
        final isAcc = res?.isAccepted ?? true;
        final flag = isAcc ? 'ACCEPTED' : (res?.rejectionReason?.contains('FLAG') ?? false ? 'FLAGGED' : 'REJECTED');

        markers.add(
          MapStationMarker(
            stationId: st.id,
            sequenceNumber: st.sequenceNumber,
            x: x,
            y: y,
            latitude: st.latitude,
            longitude: st.longitude,
            totalFieldNt: tf,
            diurnalCorrectionNt: anom?.diurnalCorrectionNt,
            fIgrfNt: anom?.fIgrfNt,
            deltaTNt: anom?.deltaTNt ?? (tf - 44500.0),
            isAccepted: isAcc,
            qualityFlag: flag,
          ),
        );
      }

      _computeGridsFromMarkers(markers);
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Gagal mengolah titik stasiun: $e');
        _generateDemoData();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateDemoData() {
    // Menghasilkan 16 titik sintetis (4x4 grid) di sekitar anomali magnetik
    final markers = <MapStationMarker>[];
    int seq = 1;
    for (int j = 0; j < 4; j++) {
      for (int i = 0; i < 4; i++) {
        final x = i * 20.0;
        final y = j * 20.0;
        final distSq = (x - 30.0) * (x - 30.0) + (y - 30.0) * (y - 30.0) + 15.0 * 15.0;
        final anomVal = 100000.0 * (450.0 - (distSq - 225.0)) / (distSq * sqrt(distSq));
        final tf = 44500.0 + anomVal;

        markers.add(
          MapStationMarker(
            stationId: 'demo-$seq',
            sequenceNumber: seq++,
            x: x,
            y: y,
            latitude: -6.2088 + (y * 0.00001),
            longitude: 106.8456 + (x * 0.00001),
            totalFieldNt: tf,
            diurnalCorrectionNt: 5.0,
            fIgrfNt: 44500.0,
            deltaTNt: anomVal,
            isAccepted: true,
            qualityFlag: 'ACCEPTED',
          ),
        );
      }
    }
    _computeGridsFromMarkers(markers);
  }

  void _computeGridsFromMarkers(List<MapStationMarker> markers) {
    if (markers.isEmpty) return;

    final tfPoints = markers
        .map((m) => GridPoint(x: m.x, y: m.y, value: m.totalFieldNt, stationId: m.stationId))
        .toList();
    final dtPoints = markers
        .map((m) => GridPoint(x: m.x, y: m.y, value: m.deltaTNt ?? 0.0, stationId: m.stationId))
        .toList();

    final tfGrid = widget.griddingService.gridInverseDistanceWeighting(
      points: tfPoints,
      nx: 25,
      ny: 25,
    );
    final dtGrid = widget.griddingService.gridInverseDistanceWeighting(
      points: dtPoints,
      nx: 25,
      ny: 25,
    );

    final asRes = widget.analyticSignalService.computeAnalyticSignal(dtGrid);
    final rtpGrid = widget.rtpService.computeStabilizedRtp(
      dtGrid,
      inclinationDeg: -20.0,
      declinationDeg: 1.0,
      pseudoInclinationDeg: 20.0,
    );

    setState(() {
      _stations = markers;
      _totalFieldGrid = tfGrid;
      _deltaTGrid = dtGrid;
      _asResult = asRes;
      _rtpGrid = rtpGrid;
      _highlightedStation = markers.isNotEmpty ? markers.first : null;
      _isLoading = false;
    });
  }

  Grid2D? get _currentActiveGrid {
    switch (_selectedLayer) {
      case MapLayerType.totalField:
        return _totalFieldGrid;
      case MapLayerType.deltaT:
        return _deltaTGrid;
      case MapLayerType.analyticSignal:
        return _asResult?.asMagnitude;
      case MapLayerType.rtp:
        return _rtpGrid;
    }
  }

  String get _currentUnit {
    switch (_selectedLayer) {
      case MapLayerType.totalField:
      case MapLayerType.deltaT:
      case MapLayerType.rtp:
        return 'nT';
      case MapLayerType.analyticSignal:
        return 'nT/m';
    }
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeGrid = _currentActiveGrid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Anomali 2D'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Panduan Membaca Peta',
            onPressed: () => _showMapGuideDialog(theme),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Ekspor Data QGIS/GIS',
            onPressed: _showExportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Reset Zoom & Posisi',
            onPressed: _resetZoom,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang',
            onPressed: () {
              if (_selectedSurveyId != null) {
                _loadSurveyData(_selectedSurveyId!);
              } else {
                _loadSurveys();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderControls(theme),
                if (_stations.length < 3)
                  _buildEmptyStateBanner(theme),
                Expanded(
                  child: Stack(
                    children: [
                      // Canvas Peta Interaktif
                      InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.5,
                        maxScale: 8.0,
                        boundaryMargin: const EdgeInsets.all(200),
                        child: Center(
                          child: activeGrid != null
                              ? SizedBox(
                                  width: 360,
                                  height: 360,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (details) {
                                      final localPos = details.localPosition;
                                      final xSpan = max(1e-6, activeGrid.xMax - activeGrid.xMin);
                                      final ySpan = max(1e-6, activeGrid.yMax - activeGrid.yMin);

                                      MapStationMarker? closest;
                                      double minDistance = double.infinity;

                                      for (final st in _stations) {
                                        final normX = (st.x - activeGrid.xMin) / xSpan;
                                        final normY = (st.y - activeGrid.yMin) / ySpan;
                                        final posX = (normX * 360.0).clamp(0.0, 360.0);
                                        final posY = (360.0 - normY * 360.0).clamp(0.0, 360.0);
                                        final dist = (Offset(posX, posY) - localPos).distance;
                                        if (dist < minDistance) {
                                          minDistance = dist;
                                          closest = st;
                                        }
                                      }

                                      // Toleransi ketukan 35px
                                      if (minDistance <= 35.0 && closest != null) {
                                        setState(() => _highlightedStation = closest);
                                      }
                                    },
                                    child: CustomPaint(
                                      painter: GridMapPainter(
                                        grid: activeGrid,
                                        stations: _stations,
                                        highlightedStation: _highlightedStation,
                                        showPath: _showPath,
                                        showStationNumbers: _showStationNumbers,
                                        onStationTapped: (st) {
                                          setState(() => _highlightedStation = st);
                                        },
                                      ),
                                    ),
                                  ),
                                )
                              : const Text('Data grid belum tersedia'),
                        ),
                      ),

                      // Kompas Arah di Sudut Kanan Atas
                      if (activeGrid != null)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: _buildCompassWidget(theme),
                        ),

                      // Colorbar Legenda di Sudut Bawah
                      if (activeGrid != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: _buildColorbarLegend(theme, activeGrid),
                        ),
                    ],
                  ),
                ),
                if (activeGrid != null && _stations.length >= 3 && _showLiveMonitor)
                  _buildLiveSensorMonitor(theme),
                if (activeGrid != null && _stations.length >= 3 && _highlightedStation != null)
                  _buildStationInfoCard(theme, _highlightedStation!),
              ],
            ),
    );
  }

  Widget _buildEmptyStateBanner(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF332A15) : Colors.amber.shade50;
    final border = isDark ? Colors.amber.shade700 : Colors.amber.shade300;
    final textTitle = isDark ? Colors.amber.shade200 : Colors.amber.shade900;
    final textBody = isDark ? Colors.white70 : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: textTitle, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Baru Ada ${_stations.length} Titik Stasiun',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textTitle,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Peta 2D memerlukan minimal 3 sampai 5 titik stasiun untuk membentuk peta sebaran gradasi warna batuan/logam. '
            'Ingin melihat contoh hasil petanya sekarang?',
            style: TextStyle(fontSize: 12, color: textBody, height: 1.3),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text(
                'Tampilkan Peta Contoh Demo Simulasi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () {
                _generateDemoData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderControls(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Column(
        children: [
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _statusMessage!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 11),
              ),
            ),
          if (_surveys.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.folder_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Survei:', style: theme.textTheme.labelMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedSurveyId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: _surveys
                        .map((s) {
                          final count = _surveyStationCounts[s.id] ?? 0;
                          return DropdownMenuItem(
                            value: s.id,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$count Titik',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedSurveyId = val);
                        _loadSurveyData(val);
                      }
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          // Toggle Layer Peta
          SegmentedButton<MapLayerType>(
            segments: const [
              ButtonSegment(
                value: MapLayerType.totalField,
                label: Text('B Obs', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: MapLayerType.deltaT,
                label: Text('Anomali ΔT', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: MapLayerType.analyticSignal,
                label: Text('|AS| 3D', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: MapLayerType.rtp,
                label: Text('RTP', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {_selectedLayer},
            onSelectionChanged: (val) {
              setState(() => _selectedLayer = val.first);
            },
          ),
          const SizedBox(height: 8),
          _buildLayerDescriptionBanner(theme),
          const SizedBox(height: 6),
          _buildMapOptionChips(theme),
        ],
      ),
    );
  }

  Widget _buildMapOptionChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            avatar: const Icon(Icons.route, size: 16),
            label: const Text('Jalur Rute', style: TextStyle(fontSize: 11)),
            selected: _showPath,
            onSelected: (val) => setState(() => _showPath = val),
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.pin_outlined, size: 16),
            label: const Text('No. Titik', style: TextStyle(fontSize: 11)),
            selected: _showStationNumbers,
            onSelected: (val) => setState(() => _showStationNumbers = val),
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.sensors, size: 16),
            label: const Text('Live Sensor', style: TextStyle(fontSize: 11)),
            selected: _showLiveMonitor,
            onSelected: (val) => setState(() => _showLiveMonitor = val),
          ),
        ],
      ),
    );
  }

  Widget _buildCompassWidget(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E242B) : Colors.white).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: _CompassNeedlePainter(),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Arah Utara (N)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'Sumbu Atas (+Y)',
                style: TextStyle(
                  fontSize: 8,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSensorMonitor(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final liveMicroT = _liveTotalFieldMicroT;
    final liveNt = _liveTotalFieldNt;

    Color badgeColor;
    String statusTitle;
    String statusDesc;
    IconData statusIcon;

    if (liveMicroT == null) {
      badgeColor = Colors.grey;
      statusTitle = 'Menghubungkan ke Sensor...';
      statusDesc = 'Bawa HP berjalan mengelilingi ruangan/area untuk memantau variasi medan.';
      statusIcon = Icons.sensors_off;
    } else if (liveMicroT > 58.0) {
      badgeColor = isDark ? Colors.redAccent : Colors.red.shade700;
      statusTitle = 'Anomali Tinggi (Terdeteksi Besi / Kabel Listrik)';
      statusDesc = 'Medan magnet melonjak tinggi di atas kondisi normal latar alami.';
      statusIcon = Icons.warning_amber_rounded;
    } else if (liveMicroT > 48.0) {
      badgeColor = isDark ? Colors.amberAccent : Colors.amber.shade800;
      statusTitle = 'Anomali Sedang (Indikasi Logam Ringan)';
      statusDesc = 'Medan sedikit di atas rata-rata lingkungan alami.';
      statusIcon = Icons.info_outline;
    } else {
      badgeColor = isDark ? Colors.greenAccent : Colors.green.shade700;
      statusTitle = 'Medan Normal (Latar Alami)';
      statusDesc = 'Kondisi stabil tanpa gangguan logam berat atau kabel arus kuat.';
      statusIcon = Icons.check_circle_outline;
    }

    // Cari stasiun terdekat yang nilainya mirip dengan bacaan live saat ini
    MapStationMarker? matchedStation;
    if (liveNt != null && _stations.isNotEmpty) {
      for (final st in _stations) {
        if ((st.totalFieldNt - liveNt).abs() < 1500.0) {
          matchedStation = st;
          break;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242B) : Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.blueGrey.shade700 : Colors.blueGrey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Monitor Sensor HP Real-Time',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              if (liveMicroT != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        '${liveMicroT.toStringAsFixed(1)} µT (${liveNt?.toStringAsFixed(0)} nT)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  statusDesc,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (matchedStation != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.near_me, size: 12, color: Colors.amber),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Nilai sensor saat ini mendekati Titik Stasiun #${matchedStation.sequenceNumber}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLayerDescriptionBanner(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    String title;
    String desc;
    IconData icon;

    switch (_selectedLayer) {
      case MapLayerType.deltaT:
        title = 'Lapisan Anomali Total (ΔT) • Rekomendasi Utama';
        desc = 'Menampilkan perbedaan kemagnetan batuan/logam lokal setelah dikurangi medan bumi normal. Warna merah menandakan benda/batuan bermagnet kuat.';
        icon = Icons.auto_awesome;
        break;
      case MapLayerType.analyticSignal:
        title = 'Lapisan Analytic Signal (|AS| 3D)';
        desc = 'Memperjelas batas tepi dan pusat anomali target di bawah tanah tanpa terpengaruh arah sudut inklinasi bumi.';
        icon = Icons.filter_tilt_shift;
        break;
      case MapLayerType.rtp:
        title = 'Lapisan Reduction to Pole (RTP)';
        desc = 'Mengoreksi pergeseran anomali magnetik ekuator agar posisi anomali tepat tegak lurus di atas objeknya.';
        icon = Icons.vertical_align_top;
        break;
      case MapLayerType.totalField:
        title = 'Lapisan Medan Total (B Obs)';
        desc = 'Kuat medan magnet total asli pembacaan sensor smartphone di lapangan tanpa koreksi IGRF.';
        icon = Icons.sensors;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6) : Colors.white70,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMapGuideDialog(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.map, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Panduan Membaca Peta Anomali',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Peta Anomali Geomagnetik menampilkan variasi nilai kemagnetan di bawah permukaan tanah dari hasil titik-titik stasiun yang Anda rekam.',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 16),
              Text(
                '1. Arti Gradasi Warna Peta (Colormap)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              _buildGuideColorItem(
                color: const Color(0xFFB20000),
                label: 'Merah / Oranye (Nilai Tinggi)',
                desc: 'Menandakan respons kemagnetan kuat di bawah tanah. Contoh: adanya batuan beku vulkanik, urat mineral besi, pipa logam terkubur, atau struktur magnetik.',
                theme: theme,
              ),
              _buildGuideColorItem(
                color: const Color(0xFF00FF00),
                label: 'Hijau / Kuning (Nilai Sedang / Netral)',
                desc: 'Kondisi medan magnet rata-rata di lingkungan sekitar (tanah biasa / batuan dasar umum).',
                theme: theme,
              ),
              _buildGuideColorItem(
                color: const Color(0xFF000080),
                label: 'Biru / Sian (Nilai Rendah / Negatif)',
                desc: 'Kondisi kemagnetan lebih rendah dari lingkungan sekitar. Contoh: batuan sedimen berpori, pasir, rongga/gua bawah tanah, atau efek kutub kebalikan magnet.',
                theme: theme,
              ),
              const SizedBox(height: 16),
              Text(
                '2. Alur Cara Memakai Fitur Peta Ini (Step-by-Step)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              _buildGuideStepItem('1', 'Pilih Survei', 'Pilih "Survei Lapangan Utama" di bagian atas untuk memuat titik stasiun rover Anda.', theme),
              _buildGuideStepItem('2', 'Pilih Jenis Lapisan', 'Gunakan "Anomali ΔT" untuk melihat sebaran anomali batuan/logam secara optimal.', theme),
              _buildGuideStepItem('3', 'Ketuk Titik Stasiun', 'Sentuh lingkaran titik pada peta untuk melihat koordinat X, Y dan nilai medan magnet stasiun tersebut.', theme),
              _buildGuideStepItem('4', 'Ekspor ke QGIS / GIS', 'Tekan tombol download di pojok kanan atas untuk mengekspor data ke format peta profesional (.asc, .geojson, .csv).', theme),
              const SizedBox(height: 16),
              Text(
                '3. Orientasi & Navigasi Lapangan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              _buildGuideStepItem('🧭', 'Kompas Arah (N)', 'Jarum di pojok kanan atas menunjukkan arah Utara (N) sesuai orientasi sumbu tegak peta (+Y).', theme),
              _buildGuideStepItem('〰️', 'Jalur Urutan Survei', 'Garis rute menghubungkan stasiun 1➔2➔3 sesuai urutan langkah Anda di lapangan.', theme),
              _buildGuideStepItem('📡', 'Monitor Sensor Live', 'Bilah sensor membaca magnetometer smartphone secara real-time saat Anda berjalan.', theme),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Saya Mengerti'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideColorItem({
    required Color color,
    required String label,
    required String desc,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(desc, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStepItem(String step, String title, String desc, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: theme.colorScheme.primary,
            child: Text(step, style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(desc, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorbarLegend(ThemeData theme, Grid2D grid) {
    final minMax = grid.minMax;
    final unit = _currentUnit;

    return Card(
      elevation: 4,
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${minMax.min.toStringAsFixed(1)} $unit',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Skala (${_selectedLayer == MapLayerType.analyticSignal ? '|AS|' : 'Medan'})',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  '${minMax.max.toStringAsFixed(1)} $unit',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF000080), // Deep blue
                    Color(0xFF00BFFF), // Cyan
                    Color(0xFF00FF00), // Green
                    Color(0xFFFFFF00), // Yellow
                    Color(0xFFFF7F00), // Orange
                    Color(0xFFB20000), // Red
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🔵 Medan Rendah', style: TextStyle(fontSize: 10, color: Colors.blue.shade300, fontWeight: FontWeight.bold)),
                Text('🟢 Normal (Alami)', style: TextStyle(fontSize: 10, color: Colors.green.shade400, fontWeight: FontWeight.bold)),
                Text('🔴 Tinggi (Logam/Kabel)', style: TextStyle(fontSize: 10, color: Colors.red.shade300, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationInfoCard(ThemeData theme, MapStationMarker st) {
    final isDark = theme.brightness == Brightness.dark;

    String interpText;
    String interpAdvice;
    Color interpColor;
    if ((st.deltaTNt ?? 0) > 100) {
      interpText = 'Anomali Tinggi (Indikasi Objek Besi / Kabel Listrik)';
      interpAdvice = 'Terdeteksi medan magnetik kuat buatan dari logam atau arus kabel.';
      interpColor = isDark ? Colors.orangeAccent : Colors.orange.shade800;
    } else if ((st.deltaTNt ?? 0) < -100) {
      interpText = 'Anomali Rendah (Sedimen / Rongga / Bawah Rata-Rata)';
      interpAdvice = 'Nilai medan di titik ini lebih rendah dibandingkan medan acuan sekitar.';
      interpColor = isDark ? Colors.lightBlueAccent : Colors.blue.shade800;
    } else {
      interpText = 'Medan Normal (Latar Alami / Bebas Gangguan)';
      interpAdvice = 'Kondisi stabil mewakili nilai medan alami lingkungan sekitar.';
      interpColor = isDark ? Colors.greenAccent : Colors.green.shade800;
    }

    // Format posisi: tampilkan lat/long jika tersedia, jika tidak tampilkan lokal
    String posisiLabel;
    String posisiValue;
    if (st.latitude != null && st.longitude != null) {
      posisiLabel = 'Lokasi (Lat, Lon)';
      posisiValue = '${st.latitude!.toStringAsFixed(5)}, ${st.longitude!.toStringAsFixed(5)}';
    } else {
      posisiLabel = 'Posisi Lokal';
      posisiValue = '(${st.x.toStringAsFixed(1)}m, ${st.y.toStringAsFixed(1)}m)';
    }

    // Format nilai medan dalam µT agar lebih mudah dibaca
    final medanMicroT = st.totalFieldNt / 1000.0;
    final anomMicroT = (st.deltaTNt ?? 0) / 1000.0;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.place, size: 18, color: Colors.amber),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Titik ${st.sequenceNumber}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(
                    st.qualityFlag,
                    style: TextStyle(
                      color: st.isAccepted
                          ? (isDark ? Colors.greenAccent : Colors.green.shade900)
                          : (isDark ? Colors.redAccent : Colors.red.shade900),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: st.isAccepted
                      ? (isDark ? const Color(0xFF142E18) : Colors.green.shade100)
                      : (isDark ? const Color(0xFF321414) : Colors.red.shade100),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Tutup Rincian',
                  onPressed: () => setState(() => _highlightedStation = null),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '• $interpText',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: interpColor),
            ),
            const SizedBox(height: 2),
            Text(
              interpAdvice,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const Divider(height: 12),
            Row(
              children: [
                Expanded(child: _metricCol(posisiLabel, posisiValue)),
                Expanded(child: _metricCol('Medan Total', '${medanMicroT.toStringAsFixed(1)} µT')),
                Expanded(child: _metricCol('Anomali ΔT', '${anomMicroT.toStringAsFixed(2)} µT')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCol(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showExportDialog() {
    final activeGrid = _currentActiveGrid;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.download, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  'Ekspor Data QGIS / GIS',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih format file geospasial untuk visualisasi di software GIS profesional (QGIS, ArcGIS, Oasis Montaj):',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.grid_on, color: Colors.orange),
              title: const Text('ESRI ASCII Grid (.asc)'),
              subtitle: Text(
                'Raster matriks 2D interpolasi (${_currentLayerTitle()})',
                style: const TextStyle(fontSize: 11),
              ),
              enabled: activeGrid != null,
              onTap: () {
                Navigator.pop(ctx);
                _handleExportAsciiGrid();
              },
            ),
            ListTile(
              leading: const Icon(Icons.place, color: Colors.green),
              title: const Text('GeoJSON Titik Stasiun (.geojson)'),
              subtitle: const Text(
                'Layer vektor WGS-84 titik koordinat dan seluruh atribut stasiun',
                style: TextStyle(fontSize: 11),
              ),
              enabled: _stations.isNotEmpty,
              onTap: () {
                Navigator.pop(ctx);
                _handleExportGeoJson();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.blue),
              title: const Text('CSV Anomali Terpadu (.csv)'),
              subtitle: const Text(
                'Tabel terintegrasi B_obs, B_diurnal, F_IGRF, dan Delta T',
                style: TextStyle(fontSize: 11),
              ),
              enabled: _stations.isNotEmpty,
              onTap: () {
                Navigator.pop(ctx);
                _handleExportCsv();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_zip, color: Colors.purple),
              title: const Text('Ekspor Semua Paket GIS (Lengkap)'),
              subtitle: const Text(
                'Simpan .asc, .geojson, dan .csv sekaligus ke memori perangkat',
                style: TextStyle(fontSize: 11),
              ),
              enabled: activeGrid != null && _stations.isNotEmpty,
              onTap: () {
                Navigator.pop(ctx);
                _handleExportAll();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _currentLayerTitle() {
    switch (_selectedLayer) {
      case MapLayerType.totalField:
        return 'Total_Field';
      case MapLayerType.deltaT:
        return 'Delta_T';
      case MapLayerType.analyticSignal:
        return 'Analytic_Signal';
      case MapLayerType.rtp:
        return 'RTP_Stabilized';
    }
  }

  Future<void> _handleExportAsciiGrid() async {
    final grid = _currentActiveGrid;
    if (grid == null) return;

    try {
      final dir = await widget.exportService.getDefaultExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final layerSlug = _currentLayerTitle().toLowerCase();
      final fileName = 'geomag_grid_${layerSlug}_$timestamp.asc';
      final file = await widget.exportService.exportAsciiGridToFile(
        grid: grid,
        filePath: '${dir.path}/$fileName',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil mengekspor ESRI ASCII Grid ke:\n${file.path}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor ESRI ASCII Grid: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleExportGeoJson() async {
    if (_stations.isEmpty) return;

    try {
      final dir = await widget.exportService.getDefaultExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'geomag_stations_$timestamp.geojson';
      final file = await widget.exportService.exportGeoJsonToFile(
        stations: _stations,
        filePath: '${dir.path}/$fileName',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil mengekspor GeoJSON ke:\n${file.path}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor GeoJSON: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleExportCsv() async {
    if (_stations.isEmpty) return;

    try {
      final dir = await widget.exportService.getDefaultExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'geomag_anomalies_$timestamp.csv';
      final file = await widget.exportService.exportCsvToFile(
        stations: _stations,
        filePath: '${dir.path}/$fileName',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil mengekspor CSV anomali ke:\n${file.path}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor CSV: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleExportAll() async {
    await _handleExportAsciiGrid();
    await _handleExportGeoJson();
    await _handleExportCsv();
  }
}

/// CustomPainter untuk merender raster grid colormap dan titik stasiun.
class GridMapPainter extends CustomPainter {
  final Grid2D grid;
  final List<MapStationMarker> stations;
  final MapStationMarker? highlightedStation;
  final ValueChanged<MapStationMarker>? onStationTapped;
  final bool showPath;
  final bool showStationNumbers;

  const GridMapPainter({
    required this.grid,
    required this.stations,
    this.highlightedStation,
    this.onStationTapped,
    this.showPath = true,
    this.showStationNumbers = true,
  });

  /// Mengonversi nilai terdistribusi [0, 1] menjadi palet warna Turbo / Geophysics.
  static Color getGeophysicsColor(double t) {
    final clamped = t.clamp(0.0, 1.0);

    // 6 Titik Kontrol Palet Geofisika:
    // 0.0: Deep Blue (0, 0, 128)
    // 0.2: Cyan (0, 191, 255)
    // 0.4: Green (0, 255, 0)
    // 0.6: Yellow (255, 255, 0)
    // 0.8: Orange (255, 127, 0)
    // 1.0: Deep Red (178, 0, 0)
    final stops = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
    final colors = [
      const Color(0xFF000080),
      const Color(0xFF00BFFF),
      const Color(0xFF00FF00),
      const Color(0xFFFFFF00),
      const Color(0xFFFF7F00),
      const Color(0xFFB20000),
    ];

    int i = 0;
    while (i < stops.length - 1 && clamped > stops[i + 1]) {
      i++;
    }

    if (i >= stops.length - 1) return colors.last;

    final tSub = (clamped - stops[i]) / (stops[i + 1] - stops[i]);
    return Color.lerp(colors[i], colors[i + 1], tSub)!;
  }

  void _drawSegmentArrow(Canvas canvas, Offset p1, Offset p2) {
    final dist = (p2 - p1).distance;
    if (dist < 28.0) return;
    final mid = (p1 + p2) / 2;
    final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    const arrowSize = 6.0;

    final path = Path()
      ..moveTo(
        mid.dx + arrowSize * cos(angle),
        mid.dy + arrowSize * sin(angle),
      )
      ..lineTo(
        mid.dx + arrowSize * cos(angle + 2.5),
        mid.dy + arrowSize * sin(angle + 2.5),
      )
      ..lineTo(
        mid.dx + arrowSize * cos(angle - 2.5),
        mid.dy + arrowSize * sin(angle - 2.5),
      )
      ..close();

    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, arrowPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final nx = grid.nx;
    final ny = grid.ny;
    final minMax = grid.minMax;
    final span = max(1e-6, minMax.max - minMax.min);

    final cellWidth = size.width / nx;
    final cellHeight = size.height / ny;

    final cellPaint = Paint()..style = PaintingStyle.fill;

    // 1. Render Matriks Sel Grid (Y=0 di bawah pada koordinat spasial)
    for (int r = 0; r < ny; r++) {
      // Balik sumbu baris agar Y naik ke atas
      final canvasY = size.height - (r + 1) * cellHeight;
      for (int c = 0; c < nx; c++) {
        final canvasX = c * cellWidth;
        final val = grid.values[r][c];
        final norm = (val - minMax.min) / span;

        cellPaint.color = getGeophysicsColor(norm);
        canvas.drawRect(
          Rect.fromLTWH(canvasX, canvasY, cellWidth + 0.5, cellHeight + 0.5),
          cellPaint,
        );
      }
    }

    // 2. Render Border Grid
    final borderPaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);

    final xSpan = max(1e-6, grid.xMax - grid.xMin);
    final ySpan = max(1e-6, grid.yMax - grid.yMin);

    // 3. Render Jalur Urutan Survei (Rute Pergerakan 1➔2➔3...) jika aktif
    if (showPath && stations.length >= 2) {
      final sorted = List<MapStationMarker>.from(stations)
        ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

      final pathShadowPaint = Paint()
        ..color = Colors.black45
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      final pathLinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final path = Path();
      for (int i = 0; i < sorted.length; i++) {
        final st = sorted[i];
        final normX = (st.x - grid.xMin) / xSpan;
        final normY = (st.y - grid.yMin) / ySpan;
        final px = (normX * size.width).clamp(0.0, size.width);
        final py = (size.height - normY * size.height).clamp(0.0, size.height);
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      canvas.drawPath(path, pathShadowPaint);
      canvas.drawPath(path, pathLinePaint);

      // Gambar panah arah gerak kecil di tengah setiap segmen
      for (int i = 0; i < sorted.length - 1; i++) {
        final st1 = sorted[i];
        final st2 = sorted[i + 1];
        final p1 = Offset(
          ((st1.x - grid.xMin) / xSpan * size.width).clamp(0.0, size.width),
          (size.height - (st1.y - grid.yMin) / ySpan * size.height).clamp(0.0, size.height),
        );
        final p2 = Offset(
          ((st2.x - grid.xMin) / xSpan * size.width).clamp(0.0, size.width),
          (size.height - (st2.y - grid.yMin) / ySpan * size.height).clamp(0.0, size.height),
        );
        _drawSegmentArrow(canvas, p1, p2);
      }
    }

    // 4. Render Titik Stasiun Berangka
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black
      ..strokeWidth = 1.5;

    for (final st in stations) {
      final normX = (st.x - grid.xMin) / xSpan;
      final normY = (st.y - grid.yMin) / ySpan;

      final posX = (normX * size.width).clamp(0.0, size.width);
      final posY = (size.height - normY * size.height).clamp(0.0, size.height);

      dotPaint.color = st.isAccepted ? Colors.white : Colors.redAccent;

      final isHigh = highlightedStation?.stationId == st.stationId;

      if (isHigh) {
        // Halo ring untuk stasiun terpilih
        final haloPaint = Paint()
          ..color = Colors.amberAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5;
        canvas.drawCircle(Offset(posX, posY), showStationNumbers ? 14.0 : 9.0, haloPaint);
      }

      final radius = showStationNumbers ? 9.5 : 5.0;
      canvas.drawCircle(Offset(posX, posY), radius, dotPaint);
      canvas.drawCircle(Offset(posX, posY), radius, strokePaint);

      if (showStationNumbers) {
        final textSpan = TextSpan(
          text: '${st.sequenceNumber}',
          style: TextStyle(
            color: st.isAccepted ? Colors.black87 : Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout();
        tp.paint(
          canvas,
          Offset(posX - tp.width / 2, posY - tp.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridMapPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.stations != stations ||
        oldDelegate.highlightedStation != highlightedStation ||
        oldDelegate.showPath != showPath ||
        oldDelegate.showStationNumbers != showStationNumbers;
  }
}

/// CustomPainter untuk merender jarum kompas arah Utara (N) dan Selatan (S).
class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(cx, cy);

    final dialPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), radius, dialPaint);

    final borderPaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), radius, borderPaint);

    // Jarum Merah (Utara / N) ke Atas
    final northPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    final northPath = Path()
      ..moveTo(cx, cy - radius * 0.8)
      ..lineTo(cx - radius * 0.35, cy)
      ..lineTo(cx + radius * 0.35, cy)
      ..close();
    canvas.drawPath(northPath, northPaint);

    // Jarum Putih (Selatan / S) ke Bawah
    final southPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.fill;
    final southPath = Path()
      ..moveTo(cx, cy + radius * 0.8)
      ..lineTo(cx - radius * 0.35, cy)
      ..lineTo(cx + radius * 0.35, cy)
      ..close();
    canvas.drawPath(southPath, southPaint);

    // Titik poros tengah
    final pivotPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 2.0, pivotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
