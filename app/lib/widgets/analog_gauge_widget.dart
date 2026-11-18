import 'dart:math';
import 'package:flutter/material.dart';

/// Widget pengukur medan magnetik visual dengan jarum analog (Speedometer Gauge)
/// yang ramah pengguna, terinspirasi dari meteran Ultimate EMF Detector.
class AnalogGaugeWidget extends StatelessWidget {
  /// Nilai medan magnetik total dalam nanoTesla (nT).
  final double valueNt;

  /// Nilai minimum skala jarum (default 0 nT).
  final double minNt;

  /// Nilai maksimum skala jarum (default 100.000 nT).
  final double maxNt;

  const AnalogGaugeWidget({
    super.key,
    required this.valueNt,
    this.minNt = 0.0,
    this.maxNt = 100000.0,
  });

  /// Status kondisi medan magnetik berdasarkan kekuatan bacaan.
  ({String label, Color color, IconData icon}) get statusInfo {
    // Normal medan bumi di Indonesia berkisar antara ~38.000 - 46.000 nT.
    if (valueNt < 30000) {
      return (
        label: 'Medan Magnet Rendah',
        color: Colors.blueAccent,
        icon: Icons.south,
      );
    } else if (valueNt <= 52000) {
      return (
        label: 'Normal (Medan Alami Bumi)',
        color: Colors.green,
        icon: Icons.check_circle_outline,
      );
    } else if (valueNt <= 65000) {
      return (
        label: 'Anomali Magnetik Sedang',
        color: Colors.orange,
        icon: Icons.warning_amber_rounded,
      );
    } else {
      return (
        label: 'Terdeteksi Batuan / Logam Kuat!',
        color: Colors.redAccent,
        icon: Icons.offline_bolt,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = statusInfo;
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.speed, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Indikator Kekuatan Magnet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status.icon, size: 14, color: status.color),
                      const SizedBox(width: 4),
                      Text(
                        status.label,
                        style: TextStyle(
                          color: status.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Kanvas Jarum Meteran Analog
            SizedBox(
              height: 160,
              width: 260,
              child: CustomPaint(
                painter: _GaugePainter(
                  value: valueNt,
                  minLimit: minNt,
                  maxLimit: maxNt,
                  theme: theme,
                ),
              ),
            ),
            // Tampilan Angka Digital Utama yang Bersih dan Formal
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  valueNt.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]}.',
                      ),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: status.color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'nT (nanoTesla)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final double minLimit;
  final double maxLimit;
  final ThemeData theme;

  _GaugePainter({
    required this.value,
    required this.minLimit,
    required this.maxLimit,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.88);
    final radius = (size.width / 2 < size.height * 0.82)
        ? size.width / 2
        : size.height * 0.82;

    // Sudut busur (mulai dari 150 derajat hingga 390 derajat / total 240 derajat)
    const startAngle = 150.0 * (pi / 180.0);
    const sweepAngle = 240.0 * (pi / 180.0);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // 1. Gambar latar busur gelap / abu-abu
    trackPaint.color = Colors.grey.withValues(alpha: 0.2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // 2. Busur Zona Warna (Biru -> Hijau -> Kuning -> Merah)
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Zona Rendah (Biru): 0 - 30k
    final blueSweep = sweepAngle * (30000.0 / (maxLimit - minLimit));
    trackPaint.color = Colors.blue.withValues(alpha: 0.8);
    canvas.drawArc(arcRect, startAngle, blueSweep, false, trackPaint);

    // Zona Normal Medan Bumi (Hijau): 30k - 52k
    final greenSweep = sweepAngle * ((52000.0 - 30000.0) / (maxLimit - minLimit));
    trackPaint.color = Colors.green.withValues(alpha: 0.85);
    canvas.drawArc(arcRect, startAngle + blueSweep, greenSweep, false, trackPaint);

    // Zona Anomali Sedang (Oranye/Kuning): 52k - 65k
    final yellowSweep = sweepAngle * ((65000.0 - 52000.0) / (maxLimit - minLimit));
    trackPaint.color = Colors.orange.withValues(alpha: 0.85);
    canvas.drawArc(arcRect, startAngle + blueSweep + greenSweep, yellowSweep, false, trackPaint);

    // Zona Anomali Kuat (Merah): 65k - 100k
    final redSweep = sweepAngle * ((maxLimit - 65000.0) / (maxLimit - minLimit));
    trackPaint.color = Colors.redAccent.withValues(alpha: 0.85);
    canvas.drawArc(
      arcRect,
      startAngle + blueSweep + greenSweep + yellowSweep,
      redSweep,
      false,
      trackPaint,
    );

    // 3. Jarum Penunjuk (Needle)
    final clampedValue = value.clamp(minLimit, maxLimit);
    final ratio = (clampedValue - minLimit) / (maxLimit - minLimit);
    final needleAngle = startAngle + (ratio * sweepAngle);

    final needleLength = radius - 16;
    final needleEnd = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleEnd, needlePaint);

    // Lingkaran Poros Jarum di Tengah
    final pivotPaint = Paint()..color = theme.colorScheme.onSurface;
    canvas.drawCircle(center, 7, pivotPaint);

    final innerPivot = Paint()..color = Colors.white;
    canvas.drawCircle(center, 3, innerPivot);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
