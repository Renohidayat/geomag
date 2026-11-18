import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/widgets/live_waveform_chart.dart';

void main() {
  testWidgets('LiveWaveformChart menampilkan judul, badge LIVE, dan metrik Min/Maks',
      (tester) async {
    final history = [44000.0, 44200.0, 45100.0, 46500.0, 44800.0];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveWaveformChart(historyNt: history),
        ),
      ),
    );

    expect(find.text('Grafik Gelombang Real-Time'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Min: 44000 nT'), findsOneWidget);
    expect(find.text('Kini: 44800 nT'), findsOneWidget);
    expect(find.text('Maks: 46500 nT'), findsOneWidget);
  });
}
