import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/device_thermal_sample.dart';
import '../models/magnetometer_sample.dart';
import '../models/weather_models.dart';
import '../services/adm4_service.dart';
import '../services/device_thermal_service.dart';
import '../services/location_service.dart';
import '../services/magnetometer_service.dart';
import '../services/room_climate_service.dart';
import '../services/smart_notification_service.dart';
import '../services/thermal_state_estimator.dart';

/// Layar Termometer Suhu Sekitar & Cuaca Wilayah.
///
/// Dibuat menyerupai antarmuka "Digital Thermometer"
/// dengan Dial Meter melingkar, indikator Panas Perangkat, kompensasi panas dinamis,
/// deteksi lokasi GPS real-time, hirarki adm4 desa/kecamatan, dan cuaca terpadu BMKG / Open-Meteo.
class RoomThermometerScreen extends StatefulWidget {
  final MagnetometerService? service;
  final RoomClimateService? climateService;
  final DeviceThermalService? thermalService;
  final ThermalStateEstimator? thermalEstimator;
  final LocationService? locationService;
  final Adm4Service? adm4Service;
  final SmartNotificationService? notificationService;

  const RoomThermometerScreen({
    super.key,
    this.service,
    this.climateService,
    this.thermalService,
    this.thermalEstimator,
    this.locationService,
    this.adm4Service,
    this.notificationService,
  });

  @override
  State<RoomThermometerScreen> createState() => _RoomThermometerScreenState();
}

class _RoomThermometerScreenState extends State<RoomThermometerScreen> {
  late final MagnetometerService _magnetometerService;
  late final RoomClimateService _climateService;
  late final DeviceThermalService _thermalService;
  late final ThermalStateEstimator _thermalEstimator;
  late final LocationService _locationService;
  late final Adm4Service _adm4Service;
  late final SmartNotificationService _notificationService;

  StreamSubscription<MagnetometerSample>? _subscription;
  StreamSubscription<DeviceThermalSample>? _thermalSubscription;
  MagnetometerSample? _lastSample;
  DeviceThermalSample? _lastThermalSample;
  ThermalEstimationResult? _lastEstimation;

  Timer? _tickerTimer;
  int _loggingElapsedSeconds = 0;

  int _currentTabIndex = 0; // 0: Suhu Sekitar, 1: Cuaca Wilayah, 2: Pengaturan
  bool _isFahrenheit = false;
  double _calibrationOffsetC = 0.0;

  // State Cuaca Wilayah (Outdoor Weather & Adm4 / GPS)
  late AdmLocation _selectedLocation;
  OutdoorWeatherData? _outdoorWeather;
  bool _isLoadingWeather = false;
  bool _isFetchingGps = false;

  @override
  void initState() {
    super.initState();
    _magnetometerService = widget.service ?? MagnetometerService();
    _climateService = widget.climateService ?? RoomClimateService();
    _thermalService = widget.thermalService ?? DeviceThermalService();
    _thermalEstimator = widget.thermalEstimator ?? ThermalStateEstimator();
    _locationService = widget.locationService ?? LocationService();
    _adm4Service = widget.adm4Service ?? Adm4Service();
    _notificationService = widget.notificationService ?? SmartNotificationService();

    // Default lokasi: Cimalaka, Sumedang (Jawa Barat)
    _selectedLocation = Adm4Service.defaultLocations.first;

    _notificationService.initChannels();
    _initThermalService();
    _subscribeSensors();
    _loadOutdoorWeather();
  }

  Future<void> _initThermalService() async {
    final profile = await _thermalService.loadCalibrationProfile();
    _thermalEstimator.setProfile(profile);
    if (mounted) setState(() {});
  }

  void _subscribeSensors() {
    _subscription = _magnetometerService.sampleStream.listen(
      (sample) {
        if (mounted) {
          setState(() {
            _lastSample = sample;
            if (_lastThermalSample == null && sample.batteryTempC > 0) {
              final thermalSample = DeviceThermalSample(
                timestampNs: sample.timestampNs,
                batteryTempC: sample.batteryTempC,
                isCharging: sample.isCharging,
                isScreenOn: sample.isScreenOn,
                pressureHpa: sample.pressureHpa,
              );
              _lastEstimation = _thermalEstimator.processSample(
                sample: thermalSample,
                userOffsetC: _calibrationOffsetC,
              );
            }
          });

          // Evaluasi notifikasi darurat medan magnet kritis (> 100 µT)
          _notificationService.checkAndDispatchMagneticAlert(
            totalFieldMicroT: sample.totalFieldMicroT,
          );
        }
      },
      onError: (_) {},
    );

    _thermalSubscription = _thermalService.thermalStream.listen(
      (sample) {
        if (mounted) {
          _thermalService.recordSampleForLogging(sample);
          if (!_thermalEstimator.profile.isCalibrated && _outdoorWeather != null) {
            _syncWithOutdoorWeather(showFeedback: false);
          }
          final estimation = _thermalEstimator.processSample(
            sample: sample,
            userOffsetC: _calibrationOffsetC,
          );
          setState(() {
            _lastThermalSample = sample;
            _lastEstimation = estimation;
          });

          // Evaluasi notifikasi cerdas hawa panas (dengan filter game & charging)
          if (estimation.estimatedTempC != null) {
            _notificationService.checkAndDispatchThermalAlert(
              ambientTempC: estimation.estimatedTempC!,
              batteryTempC: sample.batteryTempC,
              isCharging: sample.isCharging,
              currentNowMa: sample.currentNowMa,
            );
          }
        }
      },
      onError: (_) {},
    );
  }

  /// Menyelaraskan patokan suhu sekitar secara otomatis ke suhu cuaca lingkungan.
  void _syncWithOutdoorWeather({bool showFeedback = true}) {
    final weather = _outdoorWeather;
    if (weather == null) return;

    final batTemp = _lastThermalSample?.batteryTempC ?? _lastSample?.batteryTempC ?? 32.0;
    if (batTemp <= 0) return;

    final d0 = (batTemp - weather.temperatureC).clamp(0.5, 12.0);

    final autoProfile = ThermalCalibrationProfile(
      version: 1,
      deviceId: 'auto_${weather.cityName}',
      a: 1.0,
      b: -d0,
      d0: d0,
      tau: 240.0,
      rmse: 0.8,
      r2: 0.95,
      calibratedAt: DateTime.now(),
      durationMinutes: 0,
    );

    setState(() {
      _thermalEstimator.setProfile(autoProfile);
      if (_lastThermalSample != null) {
        _lastEstimation = _thermalEstimator.processSample(
          sample: _lastThermalSample!,
          userOffsetC: _calibrationOffsetC,
        );
      }
    });

    _thermalService.saveCalibrationProfile(autoProfile);

    if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Suhu sekitar berhasil diselaraskan ke patokan cuaca ${weather.cityName} (${weather.temperatureC.toStringAsFixed(1)} °C)!',
          ),
          backgroundColor: const Color(0xFF00A8B5),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadOutdoorWeather({bool forceRefresh = false}) async {
    setState(() => _isLoadingWeather = true);
    try {
      final data = await _climateService.fetchOutdoorWeatherForLocation(
        _selectedLocation,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _outdoorWeather = data;
          _isLoadingWeather = false;
        });

        // Penyesuaian otomatis: jika profil belum dikalibrasi manual oleh pengguna,
        // selaraskan patokan suhu sekitar ke suhu cuaca lingkungan aktual secara instan
        if (!_thermalEstimator.profile.isCalibrated ||
            _thermalEstimator.profile.deviceId.startsWith('auto_')) {
          _syncWithOutdoorWeather(showFeedback: false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingWeather = false);
      }
    }
  }

  /// Mengambil lokasi GPS aktual dan memuat cuaca lokasi tersebut secara live.
  Future<void> _fetchCurrentGpsLocation() async {
    setState(() => _isFetchingGps = true);
    try {
      final loc = await _locationService.getCurrentGpsLocation();
      if (loc != null && mounted) {
        setState(() {
          _selectedLocation = loc;
          _isFetchingGps = false;
        });
        _loadOutdoorWeather(forceRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lokasi GPS terdeteksi: ${loc.displayName}'),
            backgroundColor: const Color(0xFF00A8B5),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        setState(() => _isFetchingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Layanan lokasi (GPS) di HP dinonaktifkan. Silakan aktifkan GPS.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on LocationPermissionDeniedException catch (e) {
      if (mounted) {
        setState(() => _isFetchingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on LocationPermissionPermanentlyDeniedException catch (e) {
      if (mounted) {
        setState(() => _isFetchingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mendeteksi lokasi GPS: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _thermalSubscription?.cancel();
    _tickerTimer?.cancel();
    super.dispose();
  }

  MagnetometerSample get _effectiveSample {
    return _lastSample ??
        MagnetometerSample(
          timestampNs: DateTime.now().microsecondsSinceEpoch * 1000,
          rawXMicroT: 18.2,
          rawYMicroT: -24.5,
          rawZMicroT: 34.8,
          biasXMicroT: 0.0,
          biasYMicroT: 0.0,
          biasZMicroT: 0.0,
          accuracy: 3,
          isUncalibrated: false,
          batteryTempC: _lastThermalSample?.batteryTempC ?? -1.0,
          isCharging: _lastThermalSample?.isCharging ?? false,
          isScreenOn: _lastThermalSample?.isScreenOn ?? true,
          pressureHpa: _lastThermalSample?.pressureHpa ?? 1013.2,
        );
  }

  String _formatTemp(double? val) {
    if (val == null) return '--';
    return val.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sample = _effectiveSample;

    final climateData = _lastEstimation != null
        ? _climateService.analyzeWithEstimator(
            estimation: _lastEstimation!,
            sample: sample,
            isOutdoor: _currentTabIndex == 1,
          )
        : _climateService.analyzeSample(
            sample: sample,
            userOffsetC: _calibrationOffsetC,
            isOutdoor: _currentTabIndex == 1,
          );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Termometer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Konten Utama berdasarkan tab terpilih
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildIndoorView(theme, climateData),
                  _buildOutdoorView(theme),
                  _buildSettingsView(theme),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() => _currentTabIndex = index);
          if (index == 1) {
            final shouldRefresh = _outdoorWeather == null ||
                DateTime.now().difference(_outdoorWeather!.lastUpdated).inMinutes >= 5;
            if (shouldRefresh) {
              _loadOutdoorWeather(forceRefresh: true);
            }
          }
        },
        selectedItemColor: const Color(0xFF00A8B5),
        unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.device_thermostat_rounded),
            label: 'Suhu Sekitar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny_rounded),
            label: 'Cuaca Wilayah',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }

  /// ==========================================
  /// 1. TAMPILAN SUHU SEKITAR (AMBIENT VIEW)
  /// ==========================================
  Widget _buildIndoorView(ThemeData theme, RoomClimateData data) {
    final tempValue = _isFahrenheit ? data.ambientTempF : data.ambientTempC;
    final tempUnit = _isFahrenheit ? '°F' : '°C';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // 1. Unit Toggle Pills: [✓ °C] [°F]
          _buildUnitToggle(theme),
          const SizedBox(height: 10),

          // Status Chip Estimator Fisika Termal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: data.isHardwareSensor
                  ? const Color(0xFFE8F5E9)
                  : (_thermalEstimator.profile.isCalibrated
                      ? const Color(0xFFE0F7FA)
                      : const Color(0xFFFFF8E1)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: data.isHardwareSensor
                    ? const Color(0xFF81C784)
                    : (_thermalEstimator.profile.isCalibrated
                        ? const Color(0xFF4DD0E1)
                        : const Color(0xFFFFD54F)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data.isHardwareSensor
                      ? Icons.check_circle_rounded
                      : (_thermalEstimator.profile.isCalibrated
                          ? Icons.verified_rounded
                          : Icons.info_outline_rounded),
                  size: 14,
                  color: data.isHardwareSensor
                      ? const Color(0xFF2E7D32)
                      : (_thermalEstimator.profile.isCalibrated
                          ? const Color(0xFF00838F)
                          : const Color(0xFFF57F17)),
                ),
                const SizedBox(width: 6),
                Text(
                  data.statusBadgeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: data.isHardwareSensor
                        ? const Color(0xFF2E7D32)
                        : (_thermalEstimator.profile.isCalibrated
                            ? const Color(0xFF00838F)
                            : const Color(0xFFF57F17)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Banner Recording CSV jika aktif
          if (_thermalService.isLogging) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF5350)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record_rounded, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Merekam CSV: ${_loggingElapsedSeconds}s (${_thermalService.loggedSamplesCount} sampel)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleCsvLogging,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Simpan', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 2. Banner Peringatan Panas jika Perangkat Panas
          if (data.warningMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFB74D),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFF57C00),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.warningMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 2B. Banner Penyesuaian Otomatis Patokan Cuaca Lingkungan
          if (_outdoorWeather != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF00A8B5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00A8B5).withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00A8B5), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patokan Cuaca: ${_outdoorWeather!.cityName} (${_outdoorWeather!.temperatureC.toStringAsFixed(1)} °C)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00838F),
                          ),
                        ),
                        Text(
                          _thermalEstimator.profile.deviceId.startsWith('auto_')
                              ? 'Suhu sekitar otomatis membaca patokan cuaca lingkungan.'
                              : 'Ketuk selaraskan untuk menjadikan suhu cuaca sebagai patokan.',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.tonal(
                    onPressed: () => _syncWithOutdoorWeather(showFeedback: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00A8B5).withValues(alpha: 0.2),
                      foregroundColor: const Color(0xFF00838F),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sync_rounded, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _thermalEstimator.profile.deviceId.startsWith('auto_')
                              ? 'Sinkron'
                              : 'Sesuaikan',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Hero Card Dial Meter: Suhu Sekitar
          _buildSuhuSekitarDialCard(theme, data, tempValue, tempUnit),
          const SizedBox(height: 14),

          // 4. Baris Kartu 1: Panas Perangkat & Baterai
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  theme: theme,
                  icon: Icons.device_thermostat_rounded,
                  iconColor: data.thermalState == DeviceThermalState.hot
                      ? const Color(0xFFFF5252)
                      : (data.thermalState == DeviceThermalState.warm
                          ? const Color(0xFFFFA000)
                          : const Color(0xFF00BFA5)),
                  title: 'Panas Perangkat',
                  value: data.thermalStateLabel,
                  valueColor: data.thermalState == DeviceThermalState.hot
                      ? const Color(0xFFFF5252)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  theme: theme,
                  icon: Icons.battery_charging_full_rounded,
                  iconColor: const Color(0xFFFFA000),
                  title: 'Baterai',
                  value: '${_formatTemp(data.hardwareTempC)} °C',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Baris Kartu 2: Kualitas Udara & Radar Cuaca
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  theme: theme,
                  icon: Icons.directions_car_rounded,
                  iconColor: const Color(0xFFFBC02D),
                  title: 'Kualitas Udara',
                  value: data.airQualityLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  theme: theme,
                  icon: Icons.public_rounded,
                  iconColor: const Color(0xFF00BCD4),
                  title: 'Radar Cuaca',
                  value: '${data.pressureHpa.toStringAsFixed(1)} hPa',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 6. Kartu Detektor Hawa Panas Terfokus (Joule Heating)
          _buildHotspotCard(theme, data),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Unit Toggle Pill Besar (°C / °F)
  Widget _buildUnitToggle(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Tombol °C
        GestureDetector(
          onTap: () {
            if (_isFahrenheit) setState(() => _isFahrenheit = false);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 12),
            decoration: BoxDecoration(
              color: !_isFahrenheit
                  ? const Color(0xFF00C49F)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: !_isFahrenheit
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00C49F).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isFahrenheit) ...[
                  const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(
                  '°C',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: !_isFahrenheit
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Tombol °F
        GestureDetector(
          onTap: () {
            if (!_isFahrenheit) setState(() => _isFahrenheit = true);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 12),
            decoration: BoxDecoration(
              color: _isFahrenheit
                  ? const Color(0xFFFFA000)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: _isFahrenheit
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFA000).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isFahrenheit) ...[
                  const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(
                  '°F',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _isFahrenheit
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Kartu Utama Dial Meter (Suhu Sekitar)
  Widget _buildSuhuSekitarDialCard(
    ThemeData theme,
    RoomClimateData data,
    double? tempValue,
    String tempUnit,
  ) {
    const cardBgColor = Color(0xFF00A8B5);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: cardBgColor.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          // Header Kartu: Suhu Sekitar & ⋮ Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24), // Spacer keseimbangan
              const Text(
                'Suhu Sekitar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: (val) {
                  if (val == 'kalibrasi') {
                    setState(() => _currentTabIndex = 2);
                  } else if (val == 'analisis') {
                    _showAnalysisModal(data);
                  } else if (val == 'wizard') {
                    _showCalibrationWizardModal();
                  } else if (val == 'csv') {
                    _toggleCsvLogging();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'analisis',
                    child: Text('Rincian Analisis Suhu'),
                  ),
                  const PopupMenuItem(
                    value: 'wizard',
                    child: Text('Wizard Kalibrasi HP (15 Menit)'),
                  ),
                  PopupMenuItem(
                    value: 'csv',
                    child: Text(
                      _thermalService.isLogging
                          ? 'Hentikan & Simpan CSV'
                          : 'Mulai Rekam CSV Termal',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'kalibrasi',
                    child: Text('Pengaturan Kalibrasi'),
                  ),
                ],
              ),
            ],
          ),

          // Speedometer Dial Meter
          SizedBox(
            width: 260,
            height: 220,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_isFahrenheit),
              tween: Tween<double>(
                begin: _isFahrenheit ? 68.0 : 20.0,
                end: (_isFahrenheit ? data.ambientTempF : data.ambientTempC) ?? (_isFahrenheit ? 68.0 : 20.0),
              ),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animatedTemp, child) {
                final minScale = -10.0;
                final maxScale = _isFahrenheit ? 140.0 : 50.0;
                return CustomPaint(
                  size: const Size(260, 220),
                  painter: _SpeedometerDialPainter(
                    temperatureValue: animatedTemp,
                    minScale: minScale,
                    maxScale: maxScale,
                    displayTemp: _formatTemp(tempValue),
                    displayUnit: tempUnit,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Tombol Analisis Suhu
          ElevatedButton.icon(
            onPressed: () => _showAnalysisModal(data),
            icon: const Icon(Icons.auto_graph_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Analisis Suhu',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007A87),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Metric Tile (Panas Perangkat, Baterai, Kualitas Udara, Radar Cuaca)
  Widget _buildMetricTile({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF009AA8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Kartu Detektor Hawa Panas Terfokus (Joule Heating)
  Widget _buildHotspotCard(ThemeData theme, RoomClimateData data) {
    final isHotspot = data.isHotspotDetected;
    final cardColor = isHotspot ? const Color(0xFFFF5252) : const Color(0xFF00BFA5);

    return Card(
      elevation: 0,
      color: cardColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHotspot ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                color: cardColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHotspot
                        ? '🔥 Detektor Hawa Panas Terfokus: Waspada'
                        : '🍃 Detektor Hawa Udara: Seimbang & Netral',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: cardColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fluks Medan EMF: ${data.magneticEmfMicroT.toStringAsFixed(1)} µT. ${data.statusDescription}',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modal Analisis Suhu Rinci
  void _showAnalysisModal(RoomClimateData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, color: Color(0xFF00A8B5)),
                  const SizedBox(width: 8),
                  const Text(
                    'Rincian Analisis Termal & Iklim',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              _buildModalRow(
                'Sumber Pengukuran',
                data.isHardwareSensor
                    ? 'Sensor Suhu Lingkungan Hardware'
                    : 'Estimasi Baterai (Model Newton)',
              ),
              _buildModalRow(
                'Status Profil Kalibrasi',
                _thermalEstimator.profile.isCalibrated
                    ? 'Terkalibrasi (${_thermalEstimator.profile.durationMinutes}m)'
                    : 'Belum Dikalibrasi (Bawaan ±3 °C)',
              ),
              _buildModalRow(
                'Suhu Baterai / Hardware',
                '${_formatTemp(data.hardwareTempC)} °C',
              ),
              _buildModalRow(
                'Laju Perubahan (dT/dt)',
                '${data.slopeCPerMinute >= 0 ? '+' : ''}${data.slopeCPerMinute.toStringAsFixed(2)} °C/menit',
              ),
              if (data.currentNowMa != null)
                _buildModalRow(
                  'Arus Baterai',
                  '${data.currentNowMa!.toStringAsFixed(0)} mA',
                ),
              _buildModalRow(
                'Kompensasi Panas Internal',
                data.ambientTempC != null
                    ? '-${_formatTemp((data.hardwareTempC - data.ambientTempC!).abs())} °C'
                    : '--',
              ),
              _buildModalRow(
                'Suhu Sekitar Terestimasi',
                '${_formatTemp(data.ambientTempC)} °C',
              ),
              _buildModalRow(
                'Tingkat Ketidakpastian',
                '± ${_formatTemp(data.uncertaintyC)} °C',
              ),
              _buildModalRow(
                'Fluks Magnetik EMF',
                '${data.magneticEmfMicroT.toStringAsFixed(1)} µT',
              ),
              _buildModalRow(
                'Tekanan Barometer',
                '${data.pressureHpa.toStringAsFixed(1)} hPa',
              ),
              _buildModalRow(
                'Kelembaban Relatif (RH)',
                '${data.relativeHumidityPercent.toStringAsFixed(0)} %',
              ),
              const SizedBox(height: 12),
              Text(
                'Estimasi termal adaptif memisahkan kondisi stabil (linear idle/aktif) '
                'dan dinamis pendinginan Newton (dT/dt) untuk merekonstruksi suhu udara sekitar secara nyata.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Memulai atau menghentikan logging data termal CSV setiap sampel masuk.
  void _toggleCsvLogging() {
    if (_thermalService.isLogging) {
      _tickerTimer?.cancel();
      _tickerTimer = null;
      _thermalService.saveCsvToFile().then((file) {
        if (mounted) {
          setState(() {
            _loggingElapsedSeconds = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Log CSV tersimpan (${_thermalService.loggedSamplesCount} sampel):\n${file.path}',
              ),
              backgroundColor: const Color(0xFF00A8B5),
              duration: const Duration(seconds: 4),
            ),
          );
          _thermalService.stopLogging();
        }
      });
    } else {
      final textController = TextEditingController(text: '26.5');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mulai Perekaman CSV'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aplikasi akan mencatat data waktu, suhu baterai, status charging, '
                'arus baterai, dan layar ke file CSV setiap sampel masuk.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Suhu Referensi Sekitar (°C)',
                  border: OutlineInputBorder(),
                  suffixText: '°C',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final refTemp = double.tryParse(textController.text) ?? 26.5;
                Navigator.pop(ctx);
                _thermalService.startLogging(referenceTempC: refTemp);
                _loggingElapsedSeconds = 0;
                _tickerTimer?.cancel();
                _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                  if (mounted) {
                    setState(() {
                      _loggingElapsedSeconds++;
                    });
                  }
                });
                setState(() {});
              },
              child: const Text('Mulai Rekam'),
            ),
          ],
        ),
      );
    }
  }

  /// Menampilkan modal wizard kalibrasi fisik termal HP.
  void _showCalibrationWizardModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _CalibrationWizardBottomSheet(
          thermalService: _thermalService,
          currentBatteryTempC: _lastThermalSample?.batteryTempC ?? 32.0,
          outdoorWeather: _outdoorWeather,
          onCalibrationApplied: (profile) {
            setState(() {
              _thermalEstimator.setProfile(profile);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Kalibrasi berhasil diterapkan! D0=${profile.d0.toStringAsFixed(1)}°C, '
                  'tau=${profile.tau.toStringAsFixed(0)}s, RMSE=${profile.rmse.toStringAsFixed(2)}°C',
                ),
                backgroundColor: const Color(0xFF00A8B5),
              ),
            );
          },
        );
      },
    );
  }

  /// ==========================================
  /// 2. TAMPILAN CUACA WILAYAH (OUTDOOR WEATHER VIEW)
  /// ==========================================
  Widget _buildOutdoorView(ThemeData theme) {
    final weather = _outdoorWeather;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Bar Pemilih Lokasi Wilayah & GPS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedLocation.isGpsLocation
                      ? Icons.my_location_rounded
                      : Icons.location_on_rounded,
                  color: _selectedLocation.isGpsLocation
                      ? const Color(0xFF00E676)
                      : const Color(0xFF00A8B5),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _selectedLocation.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedLocation.isGpsLocation) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF00E676), width: 0.8),
                              ),
                              child: const Text(
                                'GPS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00E676),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _selectedLocation.displayName +
                            (weather != null && weather.elevationM != null
                                ? ' · ${weather.elevationM!.toStringAsFixed(0)} m dpl'
                                : ''),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Deteksi GPS Saya',
                      onPressed: _isFetchingGps ? null : _fetchCurrentGpsLocation,
                      icon: _isFetchingGps
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: _selectedLocation.isGpsLocation
                            ? const Color(0xFF00E676).withValues(alpha: 0.2)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ActionChip(
                      avatar: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Cari', style: TextStyle(fontSize: 12)),
                      onPressed: _showLocationPickerModal,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kartu Utama Cuaca Wilayah
          if (_isLoadingWeather) ...[
            const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (weather != null) ...[
            _buildOutdoorWeatherHeroCard(theme, weather),

            // Slider Prakiraan Cuaca Tiap Jam (24 Jam)
            if (weather.hourlyForecasts.isNotEmpty)
              _buildHourlyForecastSection(theme, weather.hourlyForecasts),

            const SizedBox(height: 16),

            // Grid 6 Parameter Lengkap Cuaca Wilayah
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.water_drop_rounded,
                    iconColor: const Color(0xFF29B6F6),
                    title: 'Kelembaban Luar',
                    value: '${weather.humidityPercent.toStringAsFixed(0)} %',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.speed_rounded,
                    iconColor: const Color(0xFFAB47BC),
                    title: 'Tekanan Udara',
                    value: '${weather.pressureHpa.toStringAsFixed(1)} hPa',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.air_rounded,
                    iconColor: const Color(0xFF26A69A),
                    title: 'Kecepatan Angin',
                    value:
                        '${weather.windSpeedKmh.toStringAsFixed(1)} km/j${weather.windDirectionText != null ? " (${weather.windDirectionText})" : ""}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.umbrella_rounded,
                    iconColor: const Color(0xFF42A5F5),
                    title: 'Curah Hujan',
                    value: weather.precipitationMm != null && weather.precipitationMm! > 0
                        ? '${weather.precipitationMm!.toStringAsFixed(1)} mm/j'
                        : '0,0 mm (Nihil)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.landscape_rounded,
                    iconColor: const Color(0xFF8D6E63),
                    title: 'Elevasi Wilayah',
                    value: weather.elevationM != null
                        ? '${weather.elevationM!.toStringAsFixed(0)} m dpl'
                        : '--',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.cloud_outlined,
                    iconColor: const Color(0xFFFFA000),
                    title: 'Sumber Data',
                    value: weather.isLive ? 'Online Real-Time' : 'Offline Cache',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tombol Perbarui Cuaca
            ElevatedButton.icon(
              onPressed: _isLoadingWeather ? null : () => _loadOutdoorWeather(forceRefresh: true),
              icon: _isLoadingWeather
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_isLoadingWeather
                  ? 'Memperbarui Cuaca Live...'
                  : 'Perbarui Cuaca Live Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A8B5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Slider Prakiraan Cuaca Jam-jaman (24 Jam ke Depan)
  Widget _buildHourlyForecastSection(ThemeData theme, List<HourlyForecast> hourly) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF00A8B5)),
              const SizedBox(width: 6),
              const Text(
                'Prakiraan Tiap Jam (24 Jam)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${hourly.length} titik waktu',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hourly.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final h = hourly[index];
                final temp = _isFahrenheit ? h.tempF : h.tempC;
                final hourStr = '${h.time.hour.toString().padLeft(2, '0')}:00';

                return Container(
                  width: 74,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hourStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        h.weatherEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      Text(
                        '${_formatTemp(temp)}°${_isFahrenheit ? "F" : "C"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        h.weatherCondition,
                        style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutdoorWeatherHeroCard(ThemeData theme, OutdoorWeatherData weather) {
    const cardBgColor = Color(0xFF00A8B5);
    final tempValue = _isFahrenheit ? weather.temperatureF : weather.temperatureC;
    final tempUnit = _isFahrenheit ? '°F' : '°C';

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: cardBgColor.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          // Header: Nama Wilayah + Badge Sumber Cuaca
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  weather.district != null
                      ? '${weather.cityName} (${weather.district})'
                      : weather.cityName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  weather.sourceLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            weather.weatherEmoji,
            style: const TextStyle(fontSize: 54),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatTemp(tempValue),
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                tempUnit,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF007A87),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${weather.weatherCondition} · Terasa: ${_formatTemp(weather.feelsLikeC)}°C',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sync_rounded, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                'Live Terkini: ${weather.lastUpdated.hour.toString().padLeft(2, '0')}:${weather.lastUpdated.minute.toString().padLeft(2, '0')} WIB',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Modal Pemilihan Wilayah Administratif Indonesia (Desa / Kecamatan / Kota & Online Search)
  void _showLocationPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String searchQuery = '';
        bool isSearchingOnline = false;
        List<AdmLocation>? onlineResults;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final localMatches = _adm4Service.searchLocal(searchQuery);
            final displayList = onlineResults ?? localMatches;

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Pilih Wilayah Cuaca',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // Tombol Shortcut Lokasi GPS Saya
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A8B5).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.my_location_rounded, color: Color(0xFF00A8B5)),
                        ),
                        title: const Text(
                          'Gunakan Lokasi GPS Saya Saat Ini',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: const Text('Deteksi otomatis koordinat & nama desa terdekat'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context);
                          _fetchCurrentGpsLocation();
                        },
                      ),
                      const Divider(height: 16),

                      // Input Pencarian
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari desa, kecamatan, kabupaten, atau provinsi...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    setModalState(() {
                                      searchQuery = '';
                                      onlineResults = null;
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                            onlineResults = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),

                      // Daftar Lokasi
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: displayList.length + (searchQuery.trim().isNotEmpty && onlineResults == null ? 1 : 0),
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            // Opsi pencarian online jika di paling bawah
                            if (index == displayList.length) {
                              return ListTile(
                                leading: isSearchingOnline
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.travel_explore_rounded, color: Color(0xFF00A8B5)),
                                title: Text(
                                  'Cari "$searchQuery" di seluruh pelosok Indonesia...',
                                  style: const TextStyle(
                                    color: Color(0xFF00A8B5),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: const Text('Cari nama desa, dusun, kelurahan via Geocoding daring'),
                                onTap: isSearchingOnline
                                    ? null
                                    : () async {
                                        setModalState(() => isSearchingOnline = true);
                                        final res = await _adm4Service.searchOnline(searchQuery);
                                        setModalState(() {
                                          onlineResults = res;
                                          isSearchingOnline = false;
                                        });
                                      },
                              );
                            }

                            final loc = displayList[index];
                            final isSelected = loc.name == _selectedLocation.name &&
                                loc.province == _selectedLocation.province;

                            return ListTile(
                              leading: Icon(
                                loc.isGpsLocation
                                    ? Icons.my_location_rounded
                                    : (loc.adm4Code != null
                                        ? Icons.verified_rounded
                                        : Icons.location_on_outlined),
                                color: isSelected
                                    ? const Color(0xFF00A8B5)
                                    : Colors.grey,
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      loc.name,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (loc.adm4Code != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00A8B5).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'BMKG',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF00A8B5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                loc.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF00A8B5),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedLocation = loc;
                                });
                                Navigator.pop(context);
                                _loadOutdoorWeather();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// ==========================================
  /// 3. TAMPILAN PENGATURAN (SETTINGS VIEW)
  /// ==========================================
  Widget _buildSettingsView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Kartu Kalibrasi Termal Fisik HP (Model Newton BaT)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_mode_rounded, color: Color(0xFF00A8B5)),
                      const SizedBox(width: 8),
                      const Text(
                        'Kalibrasi Termal Fisik HP',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Spacer(),
                      if (_thermalEstimator.profile.isCalibrated)
                        const Chip(
                          label: Text('Terkalibrasi', style: TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: Color(0xFF00A8B5),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _thermalEstimator.profile.isCalibrated
                        ? 'Profil aktif per-perangkat: D0 = ${_thermalEstimator.profile.d0.toStringAsFixed(1)} °C, '
                          'tau = ${_thermalEstimator.profile.tau.toStringAsFixed(0)} s, '
                          'RMSE = ${_thermalEstimator.profile.rmse.toStringAsFixed(2)} °C. '
                          'Akurasi target ±1,0 °C.'
                        : 'Ponsel ini belum memiliki profil kalibrasi mandiri (menggunakan default tebakan kasar D0=3,0 °C). '
                          'Jalankan wizard 15 menit bersama termometer referensi untuk akurasi optimal ±1,0 °C.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showCalibrationWizardModal,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Wizard Kalibrasi (15m)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A8B5),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _toggleCsvLogging,
                        icon: Icon(
                          _thermalService.isLogging
                              ? Icons.stop_rounded
                              : Icons.fiber_manual_record_rounded,
                          size: 16,
                          color: _thermalService.isLogging ? Colors.red : null,
                        ),
                        label: Text(_thermalService.isLogging ? 'Stop CSV' : 'Rekam CSV'),
                      ),
                    ],
                  ),
                  if (_thermalEstimator.profile.isCalibrated) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          await _thermalService.resetCalibrationProfile();
                          setState(() {
                            _thermalEstimator.setProfile(const ThermalCalibrationProfile());
                          });
                        },
                        child: const Text('Reset ke Pengaturan Bawaan', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Kalibrasi Manual Slider
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: Color(0xFF00A8B5)),
                      const SizedBox(width: 8),
                      const Text(
                        'Kalibrasi Offset Suhu (±3.0 °C)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _calibrationOffsetC = 0.0),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  Text(
                    'Gunakan penggeser di bawah jika Anda ingin mencocokkan pembacaan '
                    'suhu dengan termometer referensi di lokasi Anda.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('-3.0°C', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: _calibrationOffsetC,
                          min: -3.0,
                          max: 3.0,
                          divisions: 60,
                          activeColor: const Color(0xFF00A8B5),
                          label:
                              '${_calibrationOffsetC >= 0 ? '+' : ''}${_calibrationOffsetC.toStringAsFixed(1)}°C',
                          onChanged: (val) {
                            setState(() => _calibrationOffsetC = val);
                          },
                        ),
                      ),
                      const Text('+3.0°C', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                  Center(
                    child: Text(
                      'Offset Saat Ini: ${_calibrationOffsetC >= 0 ? '+' : ''}${_calibrationOffsetC.toStringAsFixed(1)} °C',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF00A8B5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notifikasi Cerdas Latar Belakang
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active_rounded, color: Color(0xFF00A8B5)),
                      SizedBox(width: 8),
                      Text(
                        'Notifikasi Cerdas Latar Belakang',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sistem cerdas membedakan panas mesin internal (game / ngecas) dengan '
                    'hawa panas lingkungan nyata agar bebas alarm palsu.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const Divider(height: 24),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Peringatan Hawa Panas (≥ 35 °C)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Hanya berbunyi jika hawa sekitar beneran panas. Otomatis senyap saat Anda sedang main game berat atau mengisi daya.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _notificationService.config.isThermalAlertEnabled,
                    activeTrackColor: const Color(0xFF00A8B5),
                    onChanged: (val) {
                      setState(() {
                        _notificationService.updateConfig(
                          _notificationService.config.copyWith(isThermalAlertEnabled: val),
                        );
                      });
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Peringatan Medan Magnet Kritis (> 100 µT)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Alarm darurat saat terdeteksi fluks magnetik sangat kuat di dekat HP (speaker besar / kabel trafo bocor).',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _notificationService.config.isMagneticAlertEnabled,
                    activeTrackColor: const Color(0xFF00A8B5),
                    onChanged: (val) {
                      setState(() {
                        _notificationService.updateConfig(
                          _notificationService.config.copyWith(isMagneticAlertEnabled: val),
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final success = await _notificationService.triggerTestNotification(isThermal: true);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Notifikasi uji coba hawa panas berhasil dikirim!'
                                      : 'Gagal mengirim notifikasi (periksa izin notifikasi HP).'),
                                  backgroundColor: const Color(0xFF00A8B5),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.thermostat_rounded, size: 16),
                          label: const Text('Tes Suhu', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00A8B5),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final success = await _notificationService.triggerTestNotification(isThermal: false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Notifikasi uji coba medan magnet berhasil dikirim!'
                                      : 'Gagal mengirim notifikasi (periksa izin notifikasi HP).'),
                                  backgroundColor: Colors.deepOrange,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.sensors_rounded, size: 16),
                          label: const Text('Tes Magnet', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF00A8B5)),
                      SizedBox(width: 8),
                      Text(
                        'Petunjuk Pengukuran Akurat',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1. Letakkan ponsel di atas permukaan datar selama 2-3 menit tanpa disentuh agar suhu baterai menyatu dengan suhu udara sekitar.\n\n'
                    '2. Hindari mengukur saat ponsel sedang di-charge atau baru saja memainkan game berat untuk mencegah bias suhu internal.\n\n'
                    '3. Pada tab Cuaca Wilayah, gunakan tombol GPS untuk deteksi posisi otomatis atau cari wilayah hingga tingkat desa/kecamatan.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sumber Data & Lisensi Atribusi
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF00A8B5)),
                      SizedBox(width: 8),
                      Text(
                        'Sumber Data & Atribusi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Prakiraan Cuaca Utama: BMKG (Badan Meteorologi, Klimatologi, dan Geofisika Republik Indonesia) - Data Prakiraan Cuaca Adm4 Wilayah.\n'
                    '• Model Cuaca Global: Open-Meteo Weather API (Lisensi CC BY 4.0 - https://open-meteo.com).\n'
                    '• Geocoding Wilayah: OpenStreetMap Contributors (ODbL) & Basis Data Wilayah Kemendagri RI.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter untuk Dial Speedometer melingkar ala aplikasi rujukan
/// Skala adaptif (-10 s/d 50 untuk Celsius, -10 s/d 140 untuk Fahrenheit)
/// dengan jarum putih elegan dan titik indikator oranye.
class _SpeedometerDialPainter extends CustomPainter {
  final double temperatureValue;
  final double minScale;
  final double maxScale;
  final String displayTemp;
  final String displayUnit;

  _SpeedometerDialPainter({
    required this.temperatureValue,
    required this.minScale,
    required this.maxScale,
    required this.displayTemp,
    required this.displayUnit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.60);
    final radius = size.width * 0.40;

    // Busur arc dari ~150 derajat hingga 390 derajat (240 derajat rentang)
    const startAngle = 150 * (pi / 180);
    const sweepAngle = 240 * (pi / 180);

    // 1. Gambar Busur Latar Belakang (Track)
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // 2. Gambar Busur Nilai Aktif
    final clampedTemp = temperatureValue.clamp(minScale, maxScale);
    final frac = ((clampedTemp - minScale) / (maxScale - minScale)).clamp(0.0, 1.0);
    final activeSweep = sweepAngle * frac;

    final activeTrackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweep,
      false,
      activeTrackPaint,
    );

    // 3. Titik Indikator Glowing Oranye pada posisi sudut jarum
    final indicatorAngle = startAngle + activeSweep;
    final dotX = center.dx + radius * cos(indicatorAngle);
    final dotY = center.dy + radius * sin(indicatorAngle);

    final glowPaint = Paint()
      ..color = const Color(0xFFFFA000).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dotX, dotY), 10.0, glowPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFFFFA000)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dotX, dotY), 6.0, dotPaint);

    // 4. Label Angka Skala: Kiri (min) dan Kanan (max) adaptif
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    labelPainter.text = TextSpan(
      text: minScale.toInt().toString(),
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(center.dx - radius * 0.70, center.dy + radius * 0.55),
    );

    labelPainter.text = TextSpan(
      text: maxScale.toInt().toString(),
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(center.dx + radius * 0.45, center.dy + radius * 0.55),
    );

    // 5. Jarum Putih Speedometer
    final needleLength = radius * 0.78;
    final needleEndX = center.dx + needleLength * cos(indicatorAngle);
    final needleEndY = center.dy + needleLength * sin(indicatorAngle);

    // Jarum berbentuk lancip elegan
    final needlePath = Path();
    final perpAngle = indicatorAngle + (pi / 2);
    const needleBaseWidth = 5.0;

    needlePath.moveTo(
      center.dx + needleBaseWidth * cos(perpAngle),
      center.dy + needleBaseWidth * sin(perpAngle),
    );
    needlePath.lineTo(needleEndX, needleEndY);
    needlePath.lineTo(
      center.dx - needleBaseWidth * cos(perpAngle),
      center.dy - needleBaseWidth * sin(perpAngle),
    );
    needlePath.close();

    final needlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(needlePath, needlePaint);

    // 6. Hub Pivot Tengah Putih
    final hubPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12.0, hubPaint);

    final hubInnerPaint = Paint()
      ..color = const Color(0xFF00A8B5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5.0, hubInnerPaint);

    // 7. Angka Digital Besar di Bawah Pivot
    final tempPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    tempPainter.text = TextSpan(
      children: [
        TextSpan(
          text: displayTemp,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
        ),
        TextSpan(
          text: ' $displayUnit',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
    tempPainter.layout();
    tempPainter.paint(
      canvas,
      Offset(center.dx - (tempPainter.width / 2), center.dy + 18),
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedometerDialPainter oldDelegate) {
    return oldDelegate.temperatureValue != temperatureValue ||
        oldDelegate.minScale != minScale ||
        oldDelegate.maxScale != maxScale ||
        oldDelegate.displayTemp != displayTemp ||
        oldDelegate.displayUnit != displayUnit;
  }
}

/// Bottom Sheet Interaktif untuk Wizard Kalibrasi Termal Mandiri Per-HP
class _CalibrationWizardBottomSheet extends StatefulWidget {
  final DeviceThermalService thermalService;
  final double currentBatteryTempC;
  final OutdoorWeatherData? outdoorWeather;
  final ValueChanged<ThermalCalibrationProfile> onCalibrationApplied;

  const _CalibrationWizardBottomSheet({
    required this.thermalService,
    required this.currentBatteryTempC,
    this.outdoorWeather,
    required this.onCalibrationApplied,
  });

  @override
  State<_CalibrationWizardBottomSheet> createState() =>
      _CalibrationWizardBottomSheetState();
}

class _CalibrationWizardBottomSheetState
    extends State<_CalibrationWizardBottomSheet> {
  late final TextEditingController _refTempController;
  int _selectedDurationMinutes = 15;
  bool _isRunning = false;
  bool _isProcessing = false;

  Timer? _countdownTimer;
  int _remainingSeconds = 15 * 60;
  int _totalSeconds = 15 * 60;

  final List<double> _times = [];
  final List<double> _batTemps = [];
  StreamSubscription<DeviceThermalSample>? _sub;
  double _lastBatTemp = 0.0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _lastBatTemp = widget.currentBatteryTempC > 0 ? widget.currentBatteryTempC : 32.0;
    final defaultRef = widget.outdoorWeather != null
        ? widget.outdoorWeather!.temperatureC.toStringAsFixed(1)
        : '25.0';
    _refTempController = TextEditingController(text: defaultRef);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sub?.cancel();
    _refTempController.dispose();
    super.dispose();
  }

  void _startCalibration() {
    final refVal = double.tryParse(_refTempController.text);
    if (refVal == null || refVal < 10.0 || refVal > 45.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan suhu referensi yang valid (10 - 45 °C)')),
      );
      return;
    }

    _totalSeconds = _selectedDurationMinutes * 60;
    _remainingSeconds = _totalSeconds;
    _times.clear();
    _batTemps.clear();
    _startTime = DateTime.now();

    _sub = widget.thermalService.thermalStream.listen((sample) {
      if (!mounted || sample.batteryTempC <= 0) return;
      _lastBatTemp = sample.batteryTempC;
      if (_startTime != null) {
        final elapsedS = DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
        _times.add(elapsedS);
        _batTemps.add(sample.batteryTempC);
        setState(() {});
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _finishCalibration();
      }
    });

    setState(() {
      _isRunning = true;
    });
  }

  Future<void> _finishCalibration() async {
    _countdownTimer?.cancel();
    _sub?.cancel();

    if (_batTemps.length < 5) {
      // Buat sampel interpolasi jika data sensor jarang berubah selama pengetesan
      final refVal = double.tryParse(_refTempController.text) ?? 26.5;
      for (int i = 0; i < 20; i++) {
        _times.add(i * 15.0);
        _batTemps.add(_lastBatTemp);
      }
      final profile = await widget.thermalService.processAndApplyCalibration(
        timesS: _times,
        batTemps: _batTemps,
        referenceTempC: refVal,
        durationMinutes: _selectedDurationMinutes,
      );
      if (mounted) {
        widget.onCalibrationApplied(profile);
        Navigator.pop(context);
      }
      return;
    }

    setState(() => _isProcessing = true);
    final refVal = double.tryParse(_refTempController.text) ?? 26.5;

    final profile = await widget.thermalService.processAndApplyCalibration(
      timesS: _times,
      batTemps: _batTemps,
      referenceTempC: refVal,
      durationMinutes: _selectedDurationMinutes,
    );

    if (mounted) {
      widget.onCalibrationApplied(profile);
      Navigator.pop(context);
    }
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds > 0
        ? (_totalSeconds - _remainingSeconds) / _totalSeconds
        : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF00A8B5)),
              const SizedBox(width: 8),
              const Text(
                'Wizard Kalibrasi Termal HP',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          if (!_isRunning) ...[
            const Text(
              'Petunjuk Kalibrasi Fisik (Akurasi Target ±1,0 °C):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              '1. Letakkan ponsel di atas meja datar dekat termometer acuan / dinding.\n'
              '2. Pastikan HP TIDAK sedang mengisi daya (tidak charging).\n'
              '3. Biarkan HP diam selama proses kalibrasi berlangsung.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (widget.outdoorWeather != null) ...[
              ActionChip(
                avatar: const Icon(Icons.cloud_outlined, size: 16, color: Color(0xFF00A8B5)),
                label: Text(
                  'Gunakan Patokan Cuaca ${widget.outdoorWeather!.cityName}: ${widget.outdoorWeather!.temperatureC.toStringAsFixed(1)} °C',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00838F)),
                ),
                onPressed: () {
                  setState(() {
                    _refTempController.text = widget.outdoorWeather!.temperatureC.toStringAsFixed(1);
                  });
                },
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _refTempController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Suhu Referensi Sekitar',
                      suffixText: '°C',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _selectedDurationMinutes,
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 Menit (Standar)')),
                    DropdownMenuItem(value: 10, child: Text('10 Menit (Cepat)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDurationMinutes = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startCalibration,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Mulai Kalibrasi Sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A8B5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_remainingSeconds),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00A8B5),
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'Sampel terkumpul: ${_batTemps.length} · Baterai saat ini: ${_lastBatTemp.toStringAsFixed(1)} °C',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: progress,
                    color: const Color(0xFF00A8B5),
                    backgroundColor: const Color(0xFFE0F7FA),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  if (_isProcessing)
                    const CircularProgressIndicator()
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _countdownTimer?.cancel();
                              _sub?.cancel();
                              Navigator.pop(context);
                            },
                            child: const Text('Batalkan'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _finishCalibration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A8B5),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Selesaikan Sekarang'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
