import 'dart:math';

import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../services/analytic_signal_service.dart';
import '../services/gridding_service.dart';

/// Jenis layer visualisasi pada peta anomali magnetik.
enum MapLayerType {
  /// Medan total hasil observasi / terkoreksi ($B_{obs}$) dalam nT.
  totalField,

  /// Anomali medan magnetik total ($\Delta T = B_{obs} - B_{diurnal} - F_{IGRF}$) dalam nT.
  deltaT,

  /// Magnitudo sinyal analitik 3D ($|AS| = \sqrt{Tx^2 + Ty^2 + Tz^2}$) dalam nT/m.
  analyticSignal,
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
  final GriddingService griddingService;
  final AnalyticSignalService analyticSignalService;

  const AnomalyMapScreen({
    super.key,
    required this.database,
    this.griddingService = const GriddingService(),
    this.analyticSignalService = const AnalyticSignalService(),
  });

  @override
  State<AnomalyMapScreen> createState() => _AnomalyMapScreenState();
}

class _AnomalyMapScreenState extends State<AnomalyMapScreen> {
  final TransformationController _transformController =
      TransformationController();

  MapLayerType _selectedLayer = MapLayerType.deltaT;
  List<Survey> _surveys = [];
  String? _selectedSurveyId;
  bool _isLoading = true;
  String? _statusMessage;

  List<MapStationMarker> _stations = [];
  Grid2D? _totalFieldGrid;
  Grid2D? _deltaTGrid;
  AnalyticSignalResult? _asResult;

  MapStationMarker? _highlightedStation;

  @override
  void initState() {
    super.initState();
    _loadSurveys();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadSurveys() async {
    setState(() => _isLoading = true);
    try {
      final allSurveys = await widget.database.select(widget.database.surveys).get();
      final roverSurveys = allSurveys.where((s) => s.mode == 'rover').toList();

      if (mounted) {
        setState(() {
          _surveys = roverSurveys;
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

    setState(() {
      _stations = markers;
      _totalFieldGrid = tfGrid;
      _deltaTGrid = dtGrid;
      _asResult = asRes;
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
    }
  }

  String get _currentUnit {
    switch (_selectedLayer) {
      case MapLayerType.totalField:
      case MapLayerType.deltaT:
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
        title: const Text('Peta Anomali Geomagnetik'),
        actions: [
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
                                  child: CustomPaint(
                                    painter: GridMapPainter(
                                      grid: activeGrid,
                                      stations: _stations,
                                      highlightedStation: _highlightedStation,
                                      onStationTapped: (st) {
                                        setState(() => _highlightedStation = st);
                                      },
                                    ),
                                  ),
                                )
                              : const Text('Data grid belum tersedia'),
                        ),
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
                if (_highlightedStation != null)
                  _buildStationInfoCard(theme, _highlightedStation!),
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
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name, overflow: TextOverflow.ellipsis),
                            ))
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
            ],
            selected: {_selectedLayer},
            onSelectionChanged: (val) {
              setState(() => _selectedLayer = val.first);
            },
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
          ],
        ),
      ),
    );
  }

  Widget _buildStationInfoCard(ThemeData theme, MapStationMarker st) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stasiun #${st.sequenceNumber} (${st.stationId})',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(
                    st.qualityFlag,
                    style: TextStyle(
                      color: st.isAccepted ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: st.isAccepted
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _metricCol('Posisi X, Y', '(${st.x.toStringAsFixed(1)}m, ${st.y.toStringAsFixed(1)}m)'),
                _metricCol('Medan Total (B)', '${st.totalFieldNt.toStringAsFixed(1)} nT'),
                _metricCol('Anomali ΔT', '${st.deltaTNt?.toStringAsFixed(1) ?? "-"} nT'),
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
}

/// CustomPainter untuk merender raster grid colormap dan titik stasiun.
class GridMapPainter extends CustomPainter {
  final Grid2D grid;
  final List<MapStationMarker> stations;
  final MapStationMarker? highlightedStation;
  final ValueChanged<MapStationMarker>? onStationTapped;

  const GridMapPainter({
    required this.grid,
    required this.stations,
    this.highlightedStation,
    this.onStationTapped,
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

    // 3. Render Titik Stasiun
    final xSpan = max(1e-6, grid.xMax - grid.xMin);
    final ySpan = max(1e-6, grid.yMax - grid.yMin);

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
          ..color = Colors.yellowAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        canvas.drawCircle(Offset(posX, posY), 9.0, haloPaint);
      }

      canvas.drawCircle(Offset(posX, posY), 5.0, dotPaint);
      canvas.drawCircle(Offset(posX, posY), 5.0, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant GridMapPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.stations != stations ||
        oldDelegate.highlightedStation != highlightedStation;
  }
}
