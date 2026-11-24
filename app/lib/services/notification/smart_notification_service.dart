import 'dart:async';
import 'package:flutter/services.dart';

/// Status evaluasi notifikasi hawa panas
enum ThermalAlertStatus {
  normal,
  alertTriggered,
  suppressedGaming,
  suppressedCharging,
  suppressedCooldown,
  disabled,
}

/// Status evaluasi notifikasi medan magnet kritis
enum MagneticAlertStatus {
  normal,
  alertTriggered,
  suppressedCooldown,
  disabled,
}

/// Hasil evaluasi notifikasi hawa panas
class ThermalAlertEvaluation {
  final ThermalAlertStatus status;
  final String message;
  final double? evaluatedTempC;
  final String? notificationTitle;
  final String? notificationBody;

  const ThermalAlertEvaluation({
    required this.status,
    required this.message,
    this.evaluatedTempC,
    this.notificationTitle,
    this.notificationBody,
  });

  bool get isTriggered => status == ThermalAlertStatus.alertTriggered;
}

/// Hasil evaluasi notifikasi anomali medan magnet
class MagneticAlertEvaluation {
  final MagneticAlertStatus status;
  final String message;
  final double? evaluatedFieldMicroT;
  final String? notificationTitle;
  final String? notificationBody;

  const MagneticAlertEvaluation({
    required this.status,
    required this.message,
    this.evaluatedFieldMicroT,
    this.notificationTitle,
    this.notificationBody,
  });

  bool get isTriggered => status == MagneticAlertStatus.alertTriggered;
}

/// Konfigurasi notifikasi cerdas
class SmartNotificationConfig {
  final bool isThermalAlertEnabled;
  final bool isMagneticAlertEnabled;
  final double thermalThresholdC;
  final double magneticThresholdMicroT;
  final double gameCurrentThresholdMa;
  final Duration thermalCooldown;
  final Duration magneticCooldown;

  const SmartNotificationConfig({
    this.isThermalAlertEnabled = true,
    this.isMagneticAlertEnabled = true,
    this.thermalThresholdC = 35.0,
    this.magneticThresholdMicroT = 100.0,
    this.gameCurrentThresholdMa = 600.0,
    this.thermalCooldown = const Duration(minutes: 15),
    this.magneticCooldown = const Duration(minutes: 5),
  });

  SmartNotificationConfig copyWith({
    bool? isThermalAlertEnabled,
    bool? isMagneticAlertEnabled,
    double? thermalThresholdC,
    double? magneticThresholdMicroT,
    double? gameCurrentThresholdMa,
    Duration? thermalCooldown,
    Duration? magneticCooldown,
  }) {
    return SmartNotificationConfig(
      isThermalAlertEnabled: isThermalAlertEnabled ?? this.isThermalAlertEnabled,
      isMagneticAlertEnabled: isMagneticAlertEnabled ?? this.isMagneticAlertEnabled,
      thermalThresholdC: thermalThresholdC ?? this.thermalThresholdC,
      magneticThresholdMicroT: magneticThresholdMicroT ?? this.magneticThresholdMicroT,
      gameCurrentThresholdMa: gameCurrentThresholdMa ?? this.gameCurrentThresholdMa,
      thermalCooldown: thermalCooldown ?? this.thermalCooldown,
      magneticCooldown: magneticCooldown ?? this.magneticCooldown,
    );
  }
}

/// Layanan Notifikasi Cerdas Latar Belakang (Smart Background Notification Service)
///
/// Menggunakan model cerdas berbasis telemetri fisik:
/// 1. Menahan alarm hawa panas saat HP sedang di-charge atau arus listrik tinggi (|I| > 600 mA)
///    akibat bermain game berat / CPU load, sehingga zero false-alarm.
/// 2. Memicu notifikasi saat suhu sekitar murni mencapai batas bahaya (>= 35 °C) dengan arus rendah.
/// 3. Memicu notifikasi darurat saat terdeteksi fluks magnetik kritis (> 100 µT).
class SmartNotificationService {
  final MethodChannel _channel;
  SmartNotificationConfig _config;

  DateTime? _lastThermalAlertTime;
  DateTime? _lastMagneticAlertTime;

  static const int kNotificationIdThermal = 2001;
  static const int kNotificationIdMagnetic = 2002;

  static const String kChannelThermalAlert = 'geomag_thermal_alert';
  static const String kChannelMagneticAlert = 'geomag_magnetic_alert';

  SmartNotificationService({
    MethodChannel? channel,
    SmartNotificationConfig? config,
  })  : _channel = channel ?? const MethodChannel('com.geomag/magnetometer_method'),
        _config = config ?? const SmartNotificationConfig();

  SmartNotificationConfig get config => _config;

  DateTime? get lastThermalAlertTime => _lastThermalAlertTime;
  DateTime? get lastMagneticAlertTime => _lastMagneticAlertTime;

  void updateConfig(SmartNotificationConfig newConfig) {
    _config = newConfig;
  }

  /// Inisialisasi channel notifikasi di Android
  Future<void> initChannels() async {
    try {
      await _channel.invokeMethod('initNotificationChannels');
    } catch (_) {}
  }

  /// Evaluasi kondisi termal murni (tanpa efek samping pemanggilan native)
  ThermalAlertEvaluation evaluateThermal({
    required double ambientTempC,
    required double batteryTempC,
    required bool isCharging,
    double? currentNowMa,
    DateTime? currentTime,
  }) {
    if (!_config.isThermalAlertEnabled) {
      return const ThermalAlertEvaluation(
        status: ThermalAlertStatus.disabled,
        message: 'Notifikasi hawa panas dinonaktifkan oleh pengguna.',
      );
    }

    // 1. Cek Charging: Jika sedang dicas, panas berasal dari listrik charger
    if (isCharging) {
      return ThermalAlertEvaluation(
        status: ThermalAlertStatus.suppressedCharging,
        message: 'HP sedang mengisi daya (charging). Alarm hawa panas diabaikan.',
        evaluatedTempC: ambientTempC,
      );
    }

    // 2. Cek Arus Baterai (mA): Jika |current| > gameCurrentThresholdMa, panas akibat beban game/CPU
    if (currentNowMa != null && currentNowMa.abs() > _config.gameCurrentThresholdMa) {
      return ThermalAlertEvaluation(
        status: ThermalAlertStatus.suppressedGaming,
        message:
            'Arus baterai tinggi (${currentNowMa.abs().toStringAsFixed(0)} mA) akibat game/beban CPU berat. Alarm hawa panas ditahan.',
        evaluatedTempC: ambientTempC,
      );
    }

    // 3. Cek Ambang Batas Suhu Bahaya
    if (ambientTempC < _config.thermalThresholdC) {
      return ThermalAlertEvaluation(
        status: ThermalAlertStatus.normal,
        message: 'Suhu sekitar (${ambientTempC.toStringAsFixed(1)} °C) masih dalam batas aman normal.',
        evaluatedTempC: ambientTempC,
      );
    }

    // 4. Cek Cooldown Periode
    final now = currentTime ?? DateTime.now();
    if (_lastThermalAlertTime != null &&
        now.difference(_lastThermalAlertTime!) < _config.thermalCooldown) {
      final remaining =
          _config.thermalCooldown - now.difference(_lastThermalAlertTime!);
      return ThermalAlertEvaluation(
        status: ThermalAlertStatus.suppressedCooldown,
        message:
            'Alarm dalam jeda cooldown (${remaining.inMinutes} menit tersisa) untuk mencegah spam.',
        evaluatedTempC: ambientTempC,
      );
    }

    // 5. Kondisi Bahaya Nyata Terpenuhi
    final title = '☀️ Peringatan Hawa Panas Ekstrem (${ambientTempC.toStringAsFixed(1)} °C)';
    const body =
        'Hawa suhu di sekitar Anda sangat panas. Disarankan berteduh dan perbanyak minum air.';

    return ThermalAlertEvaluation(
      status: ThermalAlertStatus.alertTriggered,
      message: 'Hawa sekitar mencapai batas bahaya nyata (${ambientTempC.toStringAsFixed(1)} °C).',
      evaluatedTempC: ambientTempC,
      notificationTitle: title,
      notificationBody: body,
    );
  }

  /// Evaluasi kondisi medan magnetik kritis
  MagneticAlertEvaluation evaluateMagnetic({
    required double totalFieldMicroT,
    DateTime? currentTime,
  }) {
    if (!_config.isMagneticAlertEnabled) {
      return const MagneticAlertEvaluation(
        status: MagneticAlertStatus.disabled,
        message: 'Notifikasi anomali magnetik dinonaktifkan oleh pengguna.',
      );
    }

    // Cek Ambang Batas Medan Magnet Kritis (> 100 µT)
    if (totalFieldMicroT < _config.magneticThresholdMicroT) {
      return MagneticAlertEvaluation(
        status: MagneticAlertStatus.normal,
        message: 'Medan magnet (${totalFieldMicroT.toStringAsFixed(1)} µT) berada dalam rentang wajar.',
        evaluatedFieldMicroT: totalFieldMicroT,
      );
    }

    // Cek Cooldown Periode
    final now = currentTime ?? DateTime.now();
    if (_lastMagneticAlertTime != null &&
        now.difference(_lastMagneticAlertTime!) < _config.magneticCooldown) {
      return MagneticAlertEvaluation(
        status: MagneticAlertStatus.suppressedCooldown,
        message: 'Peringatan magnetik dalam jeda cooldown.',
        evaluatedFieldMicroT: totalFieldMicroT,
      );
    }

    final title = '🧲 Peringatan Medan Magnet Kritis (${totalFieldMicroT.toStringAsFixed(1)} µT)';
    const body =
        'Terdeteksi fluks medan magnet sangat kuat (> 100 µT). Jauhkan perangkat dari sumber magnet agar sensor aman.';

    return MagneticAlertEvaluation(
      status: MagneticAlertStatus.alertTriggered,
      message: 'Medan magnet ekstrem terdeteksi (${totalFieldMicroT.toStringAsFixed(1)} µT).',
      evaluatedFieldMicroT: totalFieldMicroT,
      notificationTitle: title,
      notificationBody: body,
    );
  }

  /// Cek dan tembakkan notifikasi hawa panas jika memenuhi syarat
  Future<bool> checkAndDispatchThermalAlert({
    required double ambientTempC,
    required double batteryTempC,
    required bool isCharging,
    double? currentNowMa,
    DateTime? currentTime,
  }) async {
    final eval = evaluateThermal(
      ambientTempC: ambientTempC,
      batteryTempC: batteryTempC,
      isCharging: isCharging,
      currentNowMa: currentNowMa,
      currentTime: currentTime,
    );

    if (eval.isTriggered) {
      final now = currentTime ?? DateTime.now();
      _lastThermalAlertTime = now;
      return await _showNativeNotification(
        id: kNotificationIdThermal,
        channelId: kChannelThermalAlert,
        title: eval.notificationTitle!,
        body: eval.notificationBody!,
      );
    }

    return false;
  }

  /// Cek dan tembakkan notifikasi medan magnet kritis jika memenuhi syarat
  Future<bool> checkAndDispatchMagneticAlert({
    required double totalFieldMicroT,
    DateTime? currentTime,
  }) async {
    final eval = evaluateMagnetic(
      totalFieldMicroT: totalFieldMicroT,
      currentTime: currentTime,
    );

    if (eval.isTriggered) {
      final now = currentTime ?? DateTime.now();
      _lastMagneticAlertTime = now;
      return await _showNativeNotification(
        id: kNotificationIdMagnetic,
        channelId: kChannelMagneticAlert,
        title: eval.notificationTitle!,
        body: eval.notificationBody!,
      );
    }

    return false;
  }

  /// Kirim notifikasi uji coba langsung untuk memastikan getar dan notifikasi berfungsi
  Future<bool> triggerTestNotification({bool isThermal = true}) async {
    if (isThermal) {
      return await _showNativeNotification(
        id: kNotificationIdThermal,
        channelId: kChannelThermalAlert,
        title: '☀️ Uji Coba: Hawa Panas Ekstrem (36.5 °C)',
        body: 'Notifikasi hawa panas bekerja normal! Peringatan akan aktif saat hawa sekitar mencapai batas bahaya.',
      );
    } else {
      return await _showNativeNotification(
        id: kNotificationIdMagnetic,
        channelId: kChannelMagneticAlert,
        title: '🧲 Uji Coba: Medan Magnet Kritis (112.4 µT)',
        body: 'Notifikasi sensor magnetik bekerja normal! Peringatan akan aktif saat terdeteksi fluks medan magnet tinggi.',
      );
    }
  }

  Future<bool> _showNativeNotification({
    required int id,
    required String channelId,
    required String title,
    required String body,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('showNotification', {
        'id': id,
        'channelId': channelId,
        'title': title,
        'body': body,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
