import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/magnetometer_sample.dart';
import '../services/magnetometer_service.dart';
import '../services/room_climate_service.dart';

/// Layar Termometer Suhu Ruangan & Cuaca Luar Ruangan.
///
/// Dibuat menyerupai antarmuka "Digital Thermometer: Room Temperature"
/// dengan Dial Meter melingkar, indikator Panas Perangkat, kompensasi panas dinamis,
/// serta cuaca luar ruangan langsung via Open-Meteo API.
class RoomThermometerScreen extends StatefulWidget {
  final MagnetometerService? service;
  final RoomClimateService? climateService;

  const RoomThermometerScreen({
    super.key,
    this.service,
    this.climateService,
  });

  @override
  State<RoomThermometerScreen> createState() => _RoomThermometerScreenState();
}

class _RoomThermometerScreenState extends State<RoomThermometerScreen> {
  late final MagnetometerService _magnetometerService;
  late final RoomClimateService _climateService;

  StreamSubscription<MagnetometerSample>? _subscription;
  MagnetometerSample? _lastSample;

  int _currentTabIndex = 0; // 0: Dalam Ruangan, 1: Luar Ruangan, 2: Pengaturan
  bool _isFahrenheit = false;
  double _calibrationOffsetC = 0.0;

  // State Luar Ruangan (Outdoor Weather)
  CityLocation _selectedCity = RoomClimateService.popularCities.first;
  OutdoorWeatherData? _outdoorWeather;
  bool _isLoadingWeather = false;

  @override
  void initState() {
    super.initState();
    _magnetometerService = widget.service ?? MagnetometerService();
    _climateService = widget.climateService ?? RoomClimateService();
    _subscribeSensor();
    _loadOutdoorWeather();
  }

  void _subscribeSensor() {
    _subscription = _magnetometerService.sampleStream.listen(
      (sample) {
        if (mounted) {
          setState(() {
            _lastSample = sample;
          });
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _loadOutdoorWeather() async {
    setState(() => _isLoadingWeather = true);
    final data = await _climateService.fetchOutdoorWeather(_selectedCity);
    if (mounted) {
      setState(() {
        _outdoorWeather = data;
        _isLoadingWeather = false;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
          batteryTempC: -1.0, // Hapus fallback 35.5/27.0: tandai -1.0 jika stream belum ada data
          isCharging: false,
          isScreenOn: true,
          pressureHpa: 1013.2,
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

    final climateData = _climateService.analyzeSample(
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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFFFA000),
              size: 26,
            ),
          ),
        ],
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
          if (index == 1 && _outdoorWeather == null) {
            _loadOutdoorWeather();
          }
        },
        selectedItemColor: const Color(0xFF00A8B5),
        unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.device_thermostat_rounded),
            label: 'Dalam Ruangan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny_rounded),
            label: 'Luar Ruangan',
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
  /// 1. TAMPILAN DALAM RUANGAN (INDOOR VIEW)
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
          const SizedBox(height: 12),

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

          // 3. Hero Card Dial Meter: Suhu Kamar
          _buildSuhuKamarDialCard(theme, data, tempValue, tempUnit),
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

  /// Kartu Utama Dial Meter (Suhu Kamar)
  Widget _buildSuhuKamarDialCard(
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
          // Header Kartu: Suhu Kamar & ⋮ Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24), // Spacer keseimbangan
              const Text(
                'Suhu kamar',
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
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'analisis',
                    child: Text('Rincian Analisis Suhu'),
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
              tween: Tween<double>(begin: 20.0, end: data.ambientTempC ?? 0.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animatedTempC, child) {
                return CustomPaint(
                  size: const Size(260, 220),
                  painter: _SpeedometerDialPainter(
                    temperatureC: animatedTempC,
                    minTempC: -10.0,
                    maxTempC: 140.0,
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
                'Suhu Baterai / Hardware',
                '${_formatTemp(data.hardwareTempC)} °C',
              ),
              _buildModalRow(
                'Status Panas Perangkat',
                data.thermalStateLabel,
              ),
              _buildModalRow(
                'Kompensasi Panas Internal',
                data.ambientTempC != null
                    ? '-${_formatTemp((data.hardwareTempC - data.ambientTempC!).abs())} °C'
                    : '--',
              ),
              _buildModalRow(
                'Suhu Kamar Terestimasi',
                '${_formatTemp(data.ambientTempC)} °C',
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
                'Model kompensasi non-linear otomatis mereduksi panas internal CPU/baterai ponsel '
                'sehingga hasil pengukuran akurat sesuai kondisi udara kamar fisik.',
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
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// ==========================================
  /// 2. TAMPILAN LUAR RUANGAN (OUTDOOR VIEW)
  /// ==========================================
  Widget _buildOutdoorView(ThemeData theme) {
    final weather = _outdoorWeather;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Bar Pemilih Lokasi Kota
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF00A8B5),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCity.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _selectedCity.province,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Ganti Kota', style: TextStyle(fontSize: 12)),
                  onPressed: _showCityPickerModal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kartu Utama Cuaca Luar Ruangan
          if (_isLoadingWeather) ...[
            const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (weather != null) ...[
            _buildOutdoorWeatherHeroCard(theme, weather),
            const SizedBox(height: 16),

            // Grid 4 Detail Parameter Luar Ruangan
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
                    value: '${weather.windSpeedKmh.toStringAsFixed(1)} km/j',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.cloud_outlined,
                    iconColor: const Color(0xFFFFA000),
                    title: 'Status Data',
                    value: weather.isLive ? 'Online Live' : 'Klimatologi',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tombol Perbarui Cuaca
            OutlinedButton.icon(
              onPressed: _loadOutdoorWeather,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Perbarui Cuaca Live'),
              style: OutlinedButton.styleFrom(
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        children: [
          Text(
            'Suhu Luar Ruangan (${weather.cityName})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            weather.weatherEmoji,
            style: const TextStyle(fontSize: 54),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatTemp(tempValue),
                style: const TextStyle(
                  fontSize: 56,
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
        ],
      ),
    );
  }

  /// Modal Pemilihan Kota / Lokasi
  void _showCityPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCities = RoomClimateService.popularCities.where((c) {
              return c.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  c.province.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
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
                        'Pilih Kota / Lokasi Cuaca',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari nama kota atau provinsi...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filteredCities.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final city = filteredCities[index];
                            final isSelected = city.name == _selectedCity.name;

                            return ListTile(
                              leading: Icon(
                                Icons.location_city_rounded,
                                color: isSelected
                                    ? const Color(0xFF00A8B5)
                                    : Colors.grey,
                              ),
                              title: Text(
                                city.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(city.province),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF00A8B5),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedCity = city;
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
                    'suhu dengan termometer referensi / AC di ruangan Anda.',
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

          // Tips Pengukuran Akurat
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
                    '1. Letakkan ponsel di atas meja datar selama 2-3 menit tanpa disentuh agar suhu baterai menyatu dengan suhu udara ruangan.\n\n'
                    '2. Hindari mengukur saat ponsel sedang di-charge atau baru saja memainkan game berat untuk mencegah bias suhu internal.\n\n'
                    '3. Pada tab Luar Ruangan, Anda dapat mengganti kota untuk melihat prakiraan cuaca live dan suhu aktual di seluruh Indonesia.',
                    style: TextStyle(fontSize: 12, height: 1.5),
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
/// Skala -10 hingga 140 dengan jarum putih elegan dan titik indikator oranye.
class _SpeedometerDialPainter extends CustomPainter {
  final double temperatureC;
  final double minTempC;
  final double maxTempC;
  final String displayTemp;
  final String displayUnit;

  _SpeedometerDialPainter({
    required this.temperatureC,
    required this.minTempC,
    required this.maxTempC,
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
    final clampedTemp = temperatureC.clamp(minTempC, maxTempC);
    final frac = ((clampedTemp - minTempC) / (maxTempC - minTempC)).clamp(0.0, 1.0);
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

    // 4. Label Angka Skala: -10 dan 140 (Persis seperti rujukan)
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    labelPainter.text = const TextSpan(
      text: '-10',
      style: TextStyle(
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

    labelPainter.text = const TextSpan(
      text: '140',
      style: TextStyle(
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
    return oldDelegate.temperatureC != temperatureC ||
        oldDelegate.displayTemp != displayTemp ||
        oldDelegate.displayUnit != displayUnit;
  }
}
