import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/widgets/analog_gauge_widget.dart';

void main() {
  testWidgets('AnalogGaugeWidget menampilkan teks nilai nT dan status yang tepat',
      (tester) async {
    // 1. Uji kondisi Normal Medan Bumi (misal 45.000 nT)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalogGaugeWidget(valueNt: 45000.0),
        ),
      ),
    );

    expect(find.text('Indikator Kekuatan Magnet'), findsOneWidget);
    expect(find.text('Normal (Medan Alami Bumi)'), findsOneWidget);
    expect(find.text('45.000'), findsOneWidget);
    expect(find.text('nT (nanoTesla)'), findsOneWidget);

    // 2. Uji kondisi Terdeteksi Batuan / Logam Kuat (misal 75.000 nT)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalogGaugeWidget(valueNt: 75000.0),
        ),
      ),
    );

    expect(find.text('Terdeteksi Batuan / Logam Kuat!'), findsOneWidget);
    expect(find.text('75.000'), findsOneWidget);

    // 3. Uji kondisi Rendah (misal 25.000 nT)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalogGaugeWidget(valueNt: 25000.0),
        ),
      ),
    );

    expect(find.text('Medan Magnet Rendah'), findsOneWidget);
    expect(find.text('25.000'), findsOneWidget);
  });
}
