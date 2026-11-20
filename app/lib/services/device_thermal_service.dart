import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/device_thermal_sample.dart';
import 'thermal_state_estimator.dart';

/// Service untuk memantau status termal perangkat, mengelola kalibrasi per-HP,
/// dan mencatat data termal CSV.
class DeviceThermalService {
  static const _eventChannel = EventChannel('com.geomag/thermal_event');
  static const _methodChannel = MethodChannel('com.geomag/magnetometer_method');

  Stream<DeviceThermalSample>? _thermalStream;
  ThermalCalibrationProfile _profile = const ThermalCalibrationProfile();

  // Mode pencatatan data CSV kalibrasi
  bool _isLogging = false;
  final List<String> _csvLines = [];
  double? _calibrationReferenceTempC;
  DateTime? _logStartTime;

  ThermalCalibrationProfile get currentProfile => _profile;
  bool get isLogging => _isLogging;
  int get loggedSamplesCount => _csvLines.length;

  /// Stream pembacaan termal hardware Android.
  Stream<DeviceThermalSample> get thermalStream {
    _thermalStream ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) {
          return DeviceThermalSample.fromMap(
            event as Map<Object?, Object?>,
          );
        });
    return _thermalStream!;
  }

  /// Cek apakah hardware memiliki sensor suhu ambien fisik.
  Future<bool> checkAmbientTemperatureSensorAvailable() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('hasAmbientTemperatureSensor');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Inisialisasi service dan memuat profil kalibrasi tersimpan.
  Future<void> initialize() async {
    await loadCalibrationProfile();
  }

  /// Memuat profil kalibrasi dari storage internal HP.
  Future<ThermalCalibrationProfile> loadCalibrationProfile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/thermal_calibration_profile.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        _profile = ThermalCalibrationProfile.fromJsonString(content);
      }
    } catch (_) {
      _profile = const ThermalCalibrationProfile();
    }
    return _profile;
  }

  /// Menyimpan profil kalibrasi ke storage internal HP.
  Future<void> saveCalibrationProfile(ThermalCalibrationProfile profile) async {
    _profile = profile;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/thermal_calibration_profile.json');
      await file.writeAsString(profile.toJsonString());
    } catch (_) {}
  }

  /// Mereset kalibrasi ke pengaturan bawaan.
  Future<void> resetCalibrationProfile() async {
    _profile = const ThermalCalibrationProfile();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/thermal_calibration_profile.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Memulai perekaman CSV data kalibrasi (setiap 5 detik).
  void startLogging({double? referenceTempC}) {
    _isLogging = true;
    _calibrationReferenceTempC = referenceTempC;
    _logStartTime = DateTime.now();
    _csvLines.clear();
    // Header CSV standar
    _csvLines.add(
      'timestamp_s,battery_temp_c,is_charging,current_now_ma,is_screen_on,reference_temp_c',
    );
  }

  /// Menambahkan sampel ke catatan CSV jika sedang logging.
  void recordSampleForLogging(DeviceThermalSample sample, {double? dynamicRefTempC}) {
    if (!_isLogging || _logStartTime == null) return;

    final elapsedS = DateTime.now().difference(_logStartTime!).inMilliseconds / 1000.0;
    final refTemp = dynamicRefTempC ?? _calibrationReferenceTempC ?? 0.0;
    final line = '${elapsedS.toStringAsFixed(1)},'
        '${sample.batteryTempC.toStringAsFixed(2)},'
        '${sample.isCharging ? 1 : 0},'
        '${(sample.currentNowMa ?? 0.0).toStringAsFixed(1)},'
        '${sample.isScreenOn ? 1 : 0},'
        '${refTemp.toStringAsFixed(2)}';

    _csvLines.add(line);
  }

  /// Menghentikan logging dan mengembalikan string CSV.
  String stopLogging() {
    _isLogging = false;
    return _csvLines.join('\n');
  }

  /// Menyimpan CSV ke file di storage dokumen aplikasi.
  Future<File> saveCsvToFile({String? filename}) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = filename ?? 'thermal_log_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}/$name');
    final csvContent = _csvLines.join('\n');
    return await file.writeAsString(csvContent);
  }

  /// Menyelesaikan kalibrasi wizard dengan data sampel yang terkumpul.
  Future<ThermalCalibrationProfile> processAndApplyCalibration({
    required List<double> timesS,
    required List<double> batTemps,
    required double referenceTempC,
    required int durationMinutes,
  }) async {
    final refTemps = List<double>.filled(timesS.length, referenceTempC);
    final params = fitThermalParameters(
      timesS: timesS,
      batTemps: batTemps,
      refTemps: refTemps,
    );

    final profile = ThermalCalibrationProfile(
      version: 1,
      deviceId: 'device_calibrated',
      a: params['a'] ?? 1.0,
      b: params['b'] ?? -3.0,
      tau: params['tau'] ?? 240.0,
      d0: params['d0'] ?? 3.0,
      rmse: params['rmse'] ?? 0.0,
      r2: params['r2'] ?? 1.0,
      calibratedAt: DateTime.now(),
      durationMinutes: durationMinutes,
    );

    await saveCalibrationProfile(profile);
    return profile;
  }
}
