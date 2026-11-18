import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../services/survey_quality_report_service.dart';

/// Layar visualisasi laporan mutu otomatis (Survey Quality Report) per survei.
class SurveyQualityReportScreen extends StatefulWidget {
  final AppDatabase database;
  final String? initialSurveyId;
  final SurveyQualityReportService? reportService;

  const SurveyQualityReportScreen({
    super.key,
    required this.database,
    this.initialSurveyId,
    this.reportService,
  });

  @override
  State<SurveyQualityReportScreen> createState() =>
      _SurveyQualityReportScreenState();
}

class _SurveyQualityReportScreenState extends State<SurveyQualityReportScreen> {
  late final SurveyQualityReportService _reportService;

  List<Survey> _surveys = [];
  String? _selectedSurveyId;
  SurveyQualityReport? _report;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _reportService =
        widget.reportService ?? SurveyQualityReportService(database: widget.database);
    _loadSurveys();
  }

  Future<void> _loadSurveys() async {
    setState(() => _isLoading = true);
    try {
      final allSurveys = await widget.database.select(widget.database.surveys).get();
      final roverSurveys = allSurveys.where((s) => s.mode == 'rover').toList();

      if (mounted) {
        setState(() {
          _surveys = roverSurveys;
          if (widget.initialSurveyId != null &&
              roverSurveys.any((s) => s.id == widget.initialSurveyId)) {
            _selectedSurveyId = widget.initialSurveyId;
          } else if (roverSurveys.isNotEmpty) {
            _selectedSurveyId = roverSurveys.first.id;
          }
        });
      }

      if (_selectedSurveyId != null) {
        await _generateReportForSurvey(_selectedSurveyId!);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat survei: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateReportForSurvey(String surveyId) async {
    setState(() => _isLoading = true);
    try {
      final rep = await _reportService.generateReport(surveyId);
      if (mounted) {
        setState(() {
          _report = rep;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal mengaudit survei: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getGradeColor(QualityGrade grade) {
    switch (grade) {
      case QualityGrade.gradeA:
        return Colors.green;
      case QualityGrade.gradeB:
        return Colors.teal;
      case QualityGrade.gradeC:
        return Colors.orange;
      case QualityGrade.gradeD:
        return Colors.red;
    }
  }

  Future<void> _copyMarkdownToClipboard() async {
    if (_report == null) return;
    await Clipboard.setData(ClipboardData(text: _report!.toMarkdown()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan audit mutu berhasil disalin ke clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _exportMarkdownFile() async {
    if (_report == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/laporan_mutu_${_report!.surveyId}_$timestamp.md');
      await file.writeAsString(_report!.toMarkdown());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Laporan mutu diekspor ke:\n${file.path}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor laporan: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Mutu Survei'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Salin Markdown',
            onPressed: _report != null ? _copyMarkdownToClipboard : null,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Ekspor File Markdown',
            onPressed: _report != null ? _exportMarkdownFile : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSurveySelector(theme),
                  const SizedBox(height: 16),
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
                    )
                  else if (_report != null) ...[
                    _buildScoreCard(theme, _report!),
                    const SizedBox(height: 16),
                    _buildStationsBreakdownCard(theme, _report!),
                    const SizedBox(height: 16),
                    _buildInstrumentsCard(theme, _report!),
                    const SizedBox(height: 16),
                    _buildFindingsCard(theme, _report!),
                    const SizedBox(height: 16),
                    _buildRecommendationsCard(theme, _report!),
                  ] else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Belum ada data survei untuk diaudit.'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSurveySelector(ThemeData theme) {
    if (_surveys.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Belum ada survei rover tercatat di database.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.folder_open, size: 22),
            const SizedBox(width: 12),
            Text('Survei:', style: theme.textTheme.titleSmall),
            const SizedBox(width: 12),
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
                    _generateReportForSurvey(val);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(ThemeData theme, SurveyQualityReport r) {
    final gradeColor = _getGradeColor(r.grade);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: gradeColor.withValues(alpha: 0.6), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('SKOR MUTU SURVEI',
                style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${r.overallScore}',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: gradeColor,
                  ),
                ),
                Text(' / 100',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Chip(
              backgroundColor: gradeColor.withValues(alpha: 0.15),
              label: Text(
                r.grade.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: gradeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationsBreakdownCard(ThemeData theme, SurveyQualityReport r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kinerja Stasiun Rover', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: r.acceptedRatio,
              backgroundColor: Colors.red.withValues(alpha: 0.2),
              color: Colors.green,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol('Diterima', '${r.acceptedStations}', Colors.green),
                _statCol('Ditandai', '${r.flaggedStations}', Colors.orange),
                _statCol('Ditolak', '${r.rejectedStations}', Colors.red),
                _statCol('Total', '${r.totalStations}', theme.colorScheme.onSurface),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricCol('Rata-rata σ', '${r.meanStdDevNt.toStringAsFixed(1)} nT'),
                _metricCol('Maksimum σ', '${r.maxStdDevNt.toStringAsFixed(1)} nT'),
                _metricCol('Minimum σ', '${r.minStdDevNt.toStringAsFixed(1)} nT'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstrumentsCard(ThemeData theme, SurveyQualityReport r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audit Instrumen & Reduksi', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                r.hasCalibration ? Icons.check_circle : Icons.warning_amber,
                color: r.hasCalibration ? Colors.green : Colors.orange,
              ),
              title: const Text('Kalibrasi Ellipsoid Sensor'),
              subtitle: Text(r.hasCalibration
                  ? 'Residu: ${r.calibrationResidualNt?.toStringAsFixed(1)} nT • Umur: ${r.calibrationAgeDays} hari'
                  : 'Belum ada profil kalibrasi hard/soft iron aktif'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                r.hasBaseStation ? Icons.check_circle : Icons.info_outline,
                color: r.hasBaseStation ? Colors.green : Colors.grey,
              ),
              title: const Text('Koreksi Base Station Harian'),
              subtitle: Text(r.hasBaseStation
                  ? 'Terhubung (${r.baseStationPoints} titik drift kontinu)'
                  : 'Survei tanpa base station harian'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindingsCard(ThemeData theme, SurveyQualityReport r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility_outlined, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Temuan Teknis', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (r.findings.isEmpty)
              const Text('Tidak ada anomali atau ketidakstabilan signifikan yang terdeteksi.')
            else
              ...r.findings.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(f)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(ThemeData theme, SurveyQualityReport r) {
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_turned_in_outlined,
                    size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Text('Rekomendasi Lapangan', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (r.recommendations.isEmpty)
              const Text('Data survei memenuhi syarat mutu dan siap diolah ke peta geofisika.')
            else
              ...r.recommendations.map(
                (rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right, size: 18, color: Colors.green),
                      Expanded(child: Text(rec)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statCol(String title, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _metricCol(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
