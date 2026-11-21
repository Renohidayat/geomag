import 'dart:math';
import '../models/device_thermal_sample.dart';

/// Menghitung kemiringan regresi linear (slope) dari pasangan waktu (detik) dan nilai (°C).
/// slope = cov(t, y) / var(t) = sum((t - t_bar)(y - y_bar)) / sum((t - t_bar)^2)
/// Toleransi paritas dengan referensi Python: 1e-6.
double computeLinearSlope(List<double> timesS, List<double> values) {
  final n = timesS.length;
  if (n < 2 || values.length != n) {
    return 0.0;
  }

  double tSum = 0.0;
  double ySum = 0.0;
  for (int i = 0; i < n; i++) {
    tSum += timesS[i];
    ySum += values[i];
  }
  final tMean = tSum / n;
  final yMean = ySum / n;

  double numerator = 0.0;
  double denominator = 0.0;
  for (int i = 0; i < n; i++) {
    final dt = timesS[i] - tMean;
    final dy = values[i] - yMean;
    numerator += dt * dy;
    denominator += dt * dt;
  }

  if (denominator.abs() < 1e-12) {
    return 0.0;
  }

  return numerator / denominator;
}

/// Menghitung rolling slopes pada jendela waktu `windowS` (default 180s = 3 menit).
List<double> computeRollingSlopes(
  List<double> timesS,
  List<double> values, {
  double windowS = 180.0,
}) {
  final n = timesS.length;
  final slopes = List<double>.filled(n, 0.0);
  int startIdx = 0;

  for (int i = 0; i < n; i++) {
    final tCurrent = timesS[i];
    while (startIdx < i && (tCurrent - timesS[startIdx]) > windowS) {
      startIdx++;
    }

    final wTimes = timesS.sublist(startIdx, i + 1);
    final wValues = values.sublist(startIdx, i + 1);
    slopes[i] = computeLinearSlope(wTimes, wValues);
  }

  return slopes;
}

/// Pencocokan parameter model termal berbasis kuadrat terkecil (OLS) dan hukum pendinginan Newton:
/// (T_bat - T_ref) = D0 - tau * (dT_bat / dt)
/// T_ruang = a * T_bat + b + tau * (dT_bat / dt) dengan a = 1.0, b = -D0.
Map<String, double> fitThermalParameters({
  required List<double> timesS,
  required List<double> batTemps,
  required List<double> refTemps,
  double windowS = 180.0,
}) {
  final n = timesS.length;
  if (n < 5 || batTemps.length != n || refTemps.length != n) {
    throw ArgumentError('Minimal 5 sampel valid diperlukan untuk kalibrasi termal.');
  }

  final slopes = computeRollingSlopes(timesS, batTemps, windowS: windowS);

  // x = -(dT_bat / dt), y = T_bat - T_ref
  final xVals = List<double>.generate(n, (i) => -slopes[i]);
  final yVals = List<double>.generate(n, (i) => batTemps[i] - refTemps[i]);

  double tau = computeLinearSlope(xVals, yVals);
  if (tau < 30.0 || tau > 600.0 || tau.isNaN) {
    tau = 240.0; // Default nominal ~4 menit
  }

  double xSum = 0.0;
  double ySum = 0.0;
  for (int i = 0; i < n; i++) {
    xSum += xVals[i];
    ySum += yVals[i];
  }
  final xMean = xSum / n;
  final yMean = ySum / n;
  double d0 = yMean - tau * xMean;

  if (d0 < 0.5 || d0 > 10.0 || d0.isNaN) {
    d0 = (ySum / n).clamp(0.5, 10.0);
  }

  const a = 1.0;
  final b = -d0;

  // Hitung residual, RMSE, dan R^2
  double sumSqRes = 0.0;
  double refSum = 0.0;
  for (int i = 0; i < n; i++) {
    refSum += refTemps[i];
    final dynCorr = (tau * slopes[i]).clamp(-3.0, 3.0);
    final tEst = a * batTemps[i] + b + dynCorr;
    final res = tEst - refTemps[i];
    sumSqRes += res * res;
  }

  final rmse = sqrt(sumSqRes / n);
  final refMean = refSum / n;

  double ssTot = 0.0;
  for (int i = 0; i < n; i++) {
    final diff = refTemps[i] - refMean;
    ssTot += diff * diff;
  }
  final r2 = ssTot > 1e-6 ? 1.0 - (sumSqRes / ssTot) : 1.0;

  return {
    'a': a,
    'b': b,
    'tau': tau,
    'd0': d0,
    'rmse': rmse,
    'r2': r2,
    'sample_count': n.toDouble(),
  };
}

/// Menghitung offset tunak D0 = mean(T_bat) - T_ref beserta simpangan baku.
Map<String, double> fitSteadyOffset(List<double> batTemps, double refTemp) {
  final n = batTemps.length;
  if (n == 0) {
    return {'d0': 3.0, 'stdDev': 0.0};
  }

  final sum = batTemps.fold<double>(0.0, (acc, t) => acc + t);
  final meanBat = sum / n;
  final d0 = meanBat - refTemp;

  double variance = 0.0;
  if (n > 1) {
    for (final t in batTemps) {
      final diff = t - meanBat;
      variance += diff * diff;
    }
    variance /= n;
  }

  return {
    'd0': d0,
    'stdDev': sqrt(variance),
  };
}

/// Estimator keadaan termal berbasis fisika untuk aplikasi GeoMag.
/// Menggabungkan deteksi keadaan dinamis, hukum Newton, dan per-device calibration.
class ThermalStateEstimator {
  final List<DeviceThermalSample> _history = [];
  ThermalCalibrationProfile _profile = const ThermalCalibrationProfile();

  int? _lastHeavyLoadTimestampNs;
  double? _lastSmoothedEstC;

  /// Ambang jendela minimum untuk evaluasi kestabilan (3 menit = 180 detik).
  static const double kMinWindowSeconds = 180.0;

  /// Ambang jendela ideal data penuh (5 menit = 300 detik).
  static const double kFullWindowSeconds = 300.0;

  /// Ambang pendinginan setelah beban berat (150 detik = 2,5 menit).
  static const int kPostLoadGracePeriodNs = 150 * 1000000000;

  /// Batas koreksi dinamik tau * dT/dt agar tidak liar (°C).
  static const double kMaxDynamicCorrectionC = 3.0;

  ThermalCalibrationProfile get profile => _profile;

  void setProfile(ThermalCalibrationProfile newProfile) {
    _profile = newProfile;
  }

  void reset() {
    _history.clear();
    _lastHeavyLoadTimestampNs = null;
    _lastSmoothedEstC = null;
  }

  /// Menambahkan sampel baru dan menghasilkan estimasi suhu ruangan.
  ThermalEstimationResult processSample({
    required DeviceThermalSample sample,
    double userOffsetC = 0.0,
  }) {
    // 1. Tangani jika sensor tidak valid (<= 0)
    if (!sample.isBatteryTempValid) {
      return ThermalEstimationResult(
        estimatedTempC: null,
        state: ThermalState.collectingData,
        slopeCPerMinute: 0.0,
        uncertaintyC: 3.0,
        statusLabel: 'Sensor tidak tersedia',
        isCalibrated: _profile.isCalibrated,
        hardwareTempC: 0.0,
        rawBatteryTempC: sample.batteryTempC,
        isCharging: sample.isCharging,
        isScreenOn: sample.isScreenOn,
        currentNowMa: sample.currentNowMa,
        isHardwareSensor: false,
      );
    }

    // 2. Jika ada sensor fisik ambient hardware (Sensor.TYPE_AMBIENT_TEMPERATURE)
    if (sample.hasAmbientHardwareSensor && sample.ambientTempHardwareC != null) {
      final ambientVal = sample.ambientTempHardwareC! + userOffsetC;
      return ThermalEstimationResult(
        estimatedTempC: ambientVal,
        state: ThermalState.hardwareAmbient,
        slopeCPerMinute: 0.0,
        uncertaintyC: 0.5,
        statusLabel: 'Sensor suhu ruang (Hardware)',
        isCalibrated: true,
        hardwareTempC: sample.batteryTempC,
        rawBatteryTempC: sample.batteryTempC,
        isCharging: sample.isCharging,
        isScreenOn: sample.isScreenOn,
        currentNowMa: sample.currentNowMa,
        isHardwareSensor: true,
      );
    }

    // 3. Tambahkan ke history dan pangkas sampel lebih lama dari kFullWindowSeconds
    _history.add(sample);
    final currentTsNs = sample.timestampNs;
    final cutoffTsNs = currentTsNs - (kFullWindowSeconds * 1e9).toInt();
    _history.removeWhere((s) => s.timestampNs < cutoffTsNs);

    // 4. Deteksi beban berat / charging
    final isCurrentHigh = sample.currentNowMa != null && sample.currentNowMa!.abs() > 800.0;
    final isHeavyLoad = sample.isCharging || isCurrentHigh;

    if (isHeavyLoad) {
      _lastHeavyLoadTimestampNs = currentTsNs;
    }

    // 5. Hitung durasi data yang terkumpul dalam history
    final firstTsNs = _history.first.timestampNs;
    final windowDurationS = (currentTsNs - firstTsNs) / 1e9;

    // 6. Hitung kemiringan dT/dt via regresi linear
    final timesS = _history.map((s) => (s.timestampNs - firstTsNs) / 1e9).toList();
    final tempsC = _history.map((s) => s.batteryTempC).toList();
    final slopeCPerS = computeLinearSlope(timesS, tempsC);
    final slopeCPerMinute = slopeCPerS * 60.0;

    // 7. Periksa apakah jendela minimum sudah terpenuhi
    final isAuto = _profile.deviceId.startsWith('auto_');
    if (windowDurationS < kMinWindowSeconds) {
      final currentMinute = (windowDurationS / 60.0).ceil().clamp(1, 5);
      final rawEst = sample.batteryTempC - _profile.d0 + userOffsetC;

      return ThermalEstimationResult(
        estimatedTempC: rawEst,
        state: ThermalState.collectingData,
        slopeCPerMinute: slopeCPerMinute,
        uncertaintyC: _profile.isCalibrated ? (isAuto ? 1.0 : 1.5) : 3.0,
        statusLabel: isAuto
            ? 'Penyesuaian Otomatis... ($currentMinute/5 mnt)'
            : 'Mengumpulkan data... ($currentMinute/5 menit)',
        dataCollectionProgress: '$currentMinute/5 menit',
        isCalibrated: _profile.isCalibrated,
        hardwareTempC: sample.batteryTempC,
        rawBatteryTempC: sample.batteryTempC,
        isCharging: sample.isCharging,
        isScreenOn: sample.isScreenOn,
        currentNowMa: sample.currentNowMa,
        isHardwareSensor: false,
      );
    }

    // 8. Tentukan State Termal
    ThermalState state;
    double uncertainty;
    String statusLabel;

    final inGracePeriod = _lastHeavyLoadTimestampNs != null &&
        (currentTsNs - _lastHeavyLoadTimestampNs!) < kPostLoadGracePeriodNs;

    if (isHeavyLoad) {
      state = ThermalState.chargingOrHeavyLoad;
      uncertainty = 3.5;
      statusLabel = 'Kurang akurat (HP panas / mengisi daya)';
    } else if (inGracePeriod) {
      state = ThermalState.coolingAfterLoad;
      uncertainty = 2.5;
      statusLabel = 'Stabilisasi pasca-beban...';
    } else if (slopeCPerMinute.abs() >= 0.05) {
      state = ThermalState.coolingOrWarming;
      uncertainty = _profile.isCalibrated ? 1.0 : 3.0;
      statusLabel = _profile.isCalibrated
          ? (isAuto ? 'Penyesuaian Otomatis (Dinamis)' : 'Terkalibrasi (Dinamis Newton)')
          : 'Belum dikalibrasi, ±3 °C';
    } else if (sample.isScreenOn) {
      state = ThermalState.activeLight;
      uncertainty = _profile.isCalibrated ? 1.0 : 3.0;
      statusLabel = _profile.isCalibrated
          ? (isAuto ? 'Penyesuaian Otomatis (Aktif)' : 'Terkalibrasi (Aktif Ringan)')
          : 'Belum dikalibrasi, ±3 °C';
    } else {
      state = ThermalState.steadyIdle;
      uncertainty = _profile.isCalibrated ? 0.8 : 2.5;
      statusLabel = _profile.isCalibrated
          ? (isAuto ? 'Penyesuaian Otomatis (Stabil)' : 'Terkalibrasi (Stabil Idle)')
          : 'Belum dikalibrasi, ±3 °C';
    }

    // 9. Hitung nilai estimasi berdasarkan state
    double rawEst;
    if (state == ThermalState.chargingOrHeavyLoad) {
      // Panas internal mendominasi: tahan estimasi terakhir yang andal atau gunakan offset besar
      rawEst = _lastSmoothedEstC ?? (sample.batteryTempC - (_profile.d0 + 4.0) + userOffsetC);
    } else if (state == ThermalState.coolingOrWarming) {
      // Model Newton: T_est = a * T_bat + b + clamp(tau * dT/dt)
      final dynCorr = (_profile.tau * slopeCPerS).clamp(
        -kMaxDynamicCorrectionC,
        kMaxDynamicCorrectionC,
      );
      rawEst = (_profile.a * sample.batteryTempC) + _profile.b + dynCorr + userOffsetC;
    } else {
      // Steady state (aktif ringan atau stabil idle)
      rawEst = (_profile.a * sample.batteryTempC) + _profile.b + userOffsetC;
    }

    // 10. Filter EMA adaptif ringan (alpha = 0.25) agar transisi angka mulus tanpa membeku
    final smoothedEst = _lastSmoothedEstC != null
        ? (_lastSmoothedEstC! * 0.75 + rawEst * 0.25)
        : rawEst;
    _lastSmoothedEstC = smoothedEst;

    return ThermalEstimationResult(
      estimatedTempC: smoothedEst,
      state: state,
      slopeCPerMinute: slopeCPerMinute,
      uncertaintyC: uncertainty,
      statusLabel: statusLabel,
      isCalibrated: _profile.isCalibrated,
      hardwareTempC: sample.batteryTempC,
      rawBatteryTempC: sample.batteryTempC,
      isCharging: sample.isCharging,
      isScreenOn: sample.isScreenOn,
      currentNowMa: sample.currentNowMa,
      isHardwareSensor: false,
    );
  }
}
