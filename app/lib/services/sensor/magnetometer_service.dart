import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';

import 'package:geomag/models/magnetometer_sample.dart';
import 'package:geomag/models/sensor_info.dart';

/// Kontrak antarmuka OOP untuk layanan pembacaan magnetometer
abstract class IMagnetometerService {
  Stream<MagnetometerSample> get sampleStream;
  Future<SensorInfo> getSensorInfo();
  Future<bool> setTargetRate(int rateHz);
}

/// Service untuk membaca magnetometer Android via platform channel.
///
/// Menggunakan EventChannel untuk streaming data sensor dan
/// MethodChannel untuk konfigurasi.
class MagnetometerService implements IMagnetometerService {
  static const _methodChannel = MethodChannel('com.geomag/magnetometer_method');
  static const _eventChannel = EventChannel('com.geomag/magnetometer_event');

  Stream<MagnetometerSample>? _sampleStream;

  // Statistik laju sampling
  int _sampleCount = 0;
  int? _lastTimestampNs;
  final List<double> _intervalMs = [];
  static const int _maxIntervalHistory = 200;

  /// Stream data magnetometer. Lazy-initialized saat pertama dipanggil.
  @override
  Stream<MagnetometerSample> get sampleStream {
    _sampleStream ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) {
          final sample = MagnetometerSample.fromEventData(
            event as Map<Object?, Object?>,
          );
          _updateStats(sample.timestampNs);
          return sample;
        });
    return _sampleStream!;
  }

  /// Ambil info sensor (nama, vendor, resolusi, dll).
  @override
  Future<SensorInfo> getSensorInfo() async {
    final result = await _methodChannel.invokeMethod<Map>('getSensorInfo');
    if (result == null) {
      return const SensorInfo(available: false, isUncalibrated: false);
    }
    return SensorInfo.fromMap(result.cast<Object?, Object?>());
  }

  /// Set laju sampling target dalam Hz.
  @override
  Future<bool> setTargetRate(int rateHz) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'setTargetRate',
      {'rateHz': rateHz},
    );
    return result ?? false;
  }

  void _updateStats(int timestampNs) {
    _sampleCount++;
    if (_lastTimestampNs != null) {
      final deltaMs = (timestampNs - _lastTimestampNs!) / 1e6;
      if (deltaMs > 0 && deltaMs < 1000) {
        _intervalMs.add(deltaMs);
        if (_intervalMs.length > _maxIntervalHistory) {
          _intervalMs.removeAt(0);
        }
      }
    }
    _lastTimestampNs = timestampNs;
  }

  /// Jumlah sampel yang diterima sejak stream mulai.
  int get sampleCount => _sampleCount;

  /// Laju sampling nyata (Hz), dihitung dari interval antar-timestamp.
  double get actualRateHz {
    if (_intervalMs.isEmpty) return 0;
    final avgMs = _intervalMs.reduce((a, b) => a + b) / _intervalMs.length;
    return avgMs > 0 ? 1000.0 / avgMs : 0;
  }

  /// Jitter (simpangan baku interval antar-sampel) dalam milidetik.
  double get jitterMs {
    if (_intervalMs.length < 2) return 0;
    final mean = _intervalMs.reduce((a, b) => a + b) / _intervalMs.length;
    final sumSqDiff = _intervalMs.fold<double>(
      0.0,
      (sum, v) => sum + (v - mean) * (v - mean),
    );
    return sqrt(sumSqDiff / (_intervalMs.length - 1));
  }

  /// Interval rata-rata antar sampel (ms).
  double get avgIntervalMs {
    if (_intervalMs.isEmpty) return 0;
    return _intervalMs.reduce((a, b) => a + b) / _intervalMs.length;
  }

  /// Reset statistik.
  void resetStats() {
    _sampleCount = 0;
    _lastTimestampNs = null;
    _intervalMs.clear();
  }
}
