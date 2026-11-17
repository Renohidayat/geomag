import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.geomag/magnetometer_method'),
      (MethodCall call) async {
        if (call.method == 'getSensorInfo') {
          return {
            'available': true,
            'isUncalibrated': true,
            'name': 'AK09918 Uncalibrated',
            'vendor': 'Asahi Kasei Microdevices',
            'version': 1,
            'resolution': 0.15,
            'maxRange': 4912.0,
            'minDelay': 20000,
            'maxDelay': 500000,
            'power': 1.1,
          };
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.geomag/magnetometer_method'),
      null,
    );
  });

  testWidgets('HomeScreen menampilkan info sensor dan tombol rekam', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    // Initial pump and pump for async getSensorInfo
    await tester.pumpAndSettle();

    expect(find.text('GeoMag'), findsOneWidget);
    expect(find.text('Info Sensor'), findsOneWidget);
    expect(find.text('AK09918 Uncalibrated'), findsOneWidget);
    expect(find.text('Uncalibrated ✓'), findsOneWidget);
    expect(find.text('Mulai Rekam'), findsOneWidget);
  });
}
