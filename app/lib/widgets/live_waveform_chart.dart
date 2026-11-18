import 'dart:math';
import 'package:flutter/material.dart';

/// Widget grafik gelombang medan magnetik real-time yang bergulir dinamis
/// (Live Scrolling Waveform Chart), terinspirasi dari aplikasi Phyphox.
class LiveWaveformChart extends StatelessWidget {
  /// Riwayat nilai medan magnetik terkini dalam nanoTesla (nT).
  final List<double> historyNt;

  /// Ketinggian kanvas grafik.
  final double height;

  const LiveWaveformChart({
    super.key,
    required this.historyNt,
    this.height = 140.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentVal = historyNt.isNotEmpty ? historyNt.last : 0.0;
    final minVal = historyNt.isNotEmpty ? historyNt.reduce(min) : 0.0;
    final maxVal = historyNt.isNotEmpty ? historyNt.reduce(max) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Grafik Gelombang Real-Time',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Garis grafik melonjak saat melintas di atas batuan magnetik atau logam',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            // Kanvas Grafik
            SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(
                  painter: _WaveformPainter(
                    values: historyNt,
                    primaryColor: theme.colorScheme.primary,
                    gridColor: isDark ? Colors.white12 : Colors.black12,
                    fillColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Indikator Ringkasan Nilai Min/Max
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Min: ${minVal.toStringAsFixed(0)} nT',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Kini: ${currentVal.toStringAsFixed(0)} nT',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Maks: ${maxVal.toStringAsFixed(0)} nT',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
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

class _WaveformPainter extends CustomPainter {
  final List<double> values;
  final Color primaryColor;
  final Color gridColor;
  final Color fillColor;

  _WaveformPainter({
    required this.values,
    required this.primaryColor,
    required this.gridColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Gambar Garis Kisi-Kisi (Gridlines)
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 3; i++) {
      final y = h * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    for (var i = 1; i <= 4; i++) {
      final x = w * (i / 5.0);
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    if (values.length < 2) return;

    // 2. Skala Nilai Min dan Max
    var minVal = values.reduce(min);
    var maxVal = values.reduce(max);

    // Berikan ruang padding vertikal minimal 500 nT agar grafik tidak gepeng
    if ((maxVal - minVal) < 500.0) {
      final mid = (minVal + maxVal) / 2.0;
      minVal = mid - 250.0;
      maxVal = mid + 250.0;
    } else {
      final span = maxVal - minVal;
      minVal -= span * 0.1;
      maxVal += span * 0.1;
    }

    final range = maxVal - minVal;

    // 3. Bangun Path Garis dan Path Isi (Area)
    final linePath = Path();
    final fillPath = Path();

    final stepX = w / (values.length - 1);

    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final normalizedY = (values[i] - minVal) / range;
      // Invert Y karena koordinat kanvas 0 di atas
      final y = h - (normalizedY * h).clamp(0.0, h);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(w, h);
    fillPath.close();

    // Gambar Area Bawah Garis
    final fillPaint = Paint()..color = fillColor;
    canvas.drawPath(fillPath, fillPaint);

    // Gambar Garis Gelombang
    final linePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Titik Terakhir (Kepala Gelombang)
    final lastNormY = (values.last - minVal) / range;
    final lastY = h - (lastNormY * h).clamp(0.0, h);
    final dotPaint = Paint()..color = Colors.redAccent;
    canvas.drawCircle(Offset(w, lastY), 4.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return true;
  }
}
