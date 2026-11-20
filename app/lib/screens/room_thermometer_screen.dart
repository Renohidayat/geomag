import 'dart:async';

import 'package:flutter/material.dart';

import '../models/magnetometer_sample.dart';
import '../services/magnetometer_service.dart';
import '../services/room_climate_service.dart';

/// Layar Termometer Suhu Ruangan & Detektor Hawa Udara Real-Time.
///
/// Menggunakan model kompensasi termal baterai HP (Overeem et al., 2013)
/// dan deteksi radiasi Joule Heating via sensor magnetometer.
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

  bool _isFahrenheit = false;
  bool _isOutdoorMode = false;
  double _calibrationOffsetC = 0.0;

  @override
  void initState() {
    super.initState();
    _magnetometerService = widget.service ?? MagnetometerService();
    _climateService = widget.climateService ?? RoomClimateService();
    _subscribeSensor();
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
      onError: (_) {
        // Tangani jika stream sensor error / fallback
      },
    );
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
          batteryTempC: 31.4,
          isCharging: false,
          isScreenOn: true,
          pressureHpa: 1012.8,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sample = _effectiveSample;

    final climateData = _climateService.analyzeSample(
      sample: sample,
      userOffsetC: _calibrationOffsetC,
      isOutdoor: _isOutdoorMode,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Termometer Ruangan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Live Climate & Thermal Scanner',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        actions: [
          // Quick Toggle °C / °F
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildUnitToggle(theme),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Mode Selector: [ Dalam Ruangan (Indoor) | Cuaca Luar (Outdoor) ]
            _buildModeSelector(theme),
            const SizedBox(height: 16),

            // 2. Hero Card: Glass Liquid Thermometer + Large Digital Readout + Status Badge
            _buildHeroThermometerCard(theme, climateData, isDark),
            const SizedBox(height: 16),

            // 3. 4 Environmental Parameter Cards (2x2 Grid)
            _buildEnvironmentalGrid(theme, climateData),
            const SizedBox(height: 16),

            // 4. Detektor Hawa Panas Terfokus (Joule Heating & Hotspot Scanner)
            _buildHotspotCard(theme, climateData),
            const SizedBox(height: 16),

            // 5. Kalibrasi Offset Suhu Ruangan (Slider ±3.0 °C)
            _buildCalibrationCard(theme),
            const SizedBox(height: 16),

            // 6. Panduan Pengukuran Presisi
            _buildGuidanceCard(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Unit Toggle Pill (°C / °F)
  Widget _buildUnitToggle(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUnitPill(label: '°C', isActive: !_isFahrenheit, theme: theme),
          _buildUnitPill(label: '°F', isActive: _isFahrenheit, theme: theme),
        ],
      ),
    );
  }

  Widget _buildUnitPill({
    required String label,
    required bool isActive,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: () {
        if ((label == '°F' && !_isFahrenheit) ||
            (label == '°C' && _isFahrenheit)) {
          setState(() {
            _isFahrenheit = label == '°F';
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isActive
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Mode Selector Pill (Indoor vs Outdoor)
  Widget _buildModeSelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              title: 'Dalam Ruangan',
              icon: Icons.home_rounded,
              isActive: !_isOutdoorMode,
              theme: theme,
              onTap: () => setState(() => _isOutdoorMode = false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildModeButton(
              title: 'Cuaca Luar',
              icon: Icons.wb_cloudy_rounded,
              isActive: _isOutdoorMode,
              theme: theme,
              onTap: () => setState(() => _isOutdoorMode = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hero Card dengan tabung termometer visual liquid & display digital
  Widget _buildHeroThermometerCard(
    ThemeData theme,
    RoomClimateData data,
    bool isDark,
  ) {
    final tempValue = _isFahrenheit ? data.ambientTempF : data.ambientTempC;
    final tempUnit = _isFahrenheit ? '°F' : '°C';

    Color statusColor;
    IconData statusIcon;

    switch (data.comfortLevel) {
      case RoomComfortLevel.hotspot:
        statusColor = const Color(0xFFFF5252);
        statusIcon = Icons.local_fire_department_rounded;
        break;
      case RoomComfortLevel.warm:
        statusColor = const Color(0xFFFFA000);
        statusIcon = Icons.wb_sunny_rounded;
        break;
      case RoomComfortLevel.cool:
        statusColor = const Color(0xFF00B0FF);
        statusIcon = Icons.ac_unit_rounded;
        break;
      case RoomComfortLevel.comfortable:
        statusColor = const Color(0xFF00C853);
        statusIcon = Icons.eco_rounded;
        break;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          children: [
            // Visual Liquid Glass Thermometer Tube
            SizedBox(
              width: 72,
              height: 220,
              child: LiquidThermometerWidget(
                temperatureC: data.ambientTempC,
                minTempC: 0.0,
                maxTempC: 50.0,
                liquidColor: statusColor,
              ),
            ),
            const SizedBox(width: 20),

            // Readout & Status Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isOutdoorMode ? 'CUACA LUAR' : 'SUHU RUANGAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (data.isCharging)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, size: 12, color: Colors.amber),
                              Text(
                                'Charging',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Large Digital Temperature Typography
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tempValue.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tempUnit,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Comfort Status Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            data.statusTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary Subtitle
                  Text(
                    'Hardware: ${data.hardwareTempC.toStringAsFixed(1)}°C · Offset: ${_calibrationOffsetC >= 0 ? '+' : ''}${_calibrationOffsetC.toStringAsFixed(1)}°C',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

  /// 4 Parameter Lingkungan dalam Grid 2x2
  Widget _buildEnvironmentalGrid(ThemeData theme, RoomClimateData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                theme: theme,
                title: 'Kelembaban Udara',
                value: '${data.relativeHumidityPercent.toStringAsFixed(0)} %',
                subtitle: 'Rentang Ideal (50-65%)',
                icon: Icons.water_drop_rounded,
                iconColor: const Color(0xFF29B6F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                theme: theme,
                title: 'Tekanan Barometer',
                value: '${data.pressureHpa.toStringAsFixed(1)} hPa',
                subtitle: 'Atmosfer Normal',
                icon: Icons.speed_rounded,
                iconColor: const Color(0xFFAB47BC),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                theme: theme,
                title: 'Medan Magnet EMF',
                value: '${data.magneticEmfMicroT.toStringAsFixed(1)} µT',
                subtitle: data.magneticEmfMicroT > 60.0
                    ? '⚠️ Terfokus Tinggi'
                    : 'Aman / Normal',
                icon: Icons.radar_rounded,
                iconColor: data.magneticEmfMicroT > 60.0
                    ? Colors.redAccent
                    : const Color(0xFF26A69A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                theme: theme,
                title: 'Suhu Chipset HP',
                value: '${data.hardwareTempC.toStringAsFixed(1)} °C',
                subtitle: 'Proksi Sensor Baterai',
                icon: Icons.memory_rounded,
                iconColor: const Color(0xFFFF7043),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required ThemeData theme,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu Analisis Hawa Panas Terfokus (Joule Heating Hotspot)
  Widget _buildHotspotCard(ThemeData theme, RoomClimateData data) {
    final isHotspot = data.isHotspotDetected;
    final cardColor = isHotspot
        ? const Color(0xFFFF5252)
        : const Color(0xFF00C853);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cardColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHotspot
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
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
                        'Detektor Hawa Panas Terfokus',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: cardColor,
                        ),
                      ),
                      Text(
                        isHotspot
                            ? 'Peringatan: Radiasi Termal & Listrik Terdeteksi'
                            : 'Kondisi Termal Ruangan Seimbang',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.statusDescription,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu Kalibrasi Manual Offset (±3.0 °C)
  Widget _buildCalibrationCard(ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Kalibrasi Offset Suhu (±3.0 °C)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _calibrationOffsetC = 0.0),
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            Text(
              'Sesuaikan offset jika suhu ruangan berbeda dengan termometer referensi / AC.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '-3.0°C',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _calibrationOffsetC,
                    min: -3.0,
                    max: 3.0,
                    divisions: 60,
                    label:
                        '${_calibrationOffsetC >= 0 ? '+' : ''}${_calibrationOffsetC.toStringAsFixed(1)}°C',
                    onChanged: (val) {
                      setState(() {
                        _calibrationOffsetC = val;
                      });
                    },
                  ),
                ),
                Text(
                  '+3.0°C',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu Petunjuk Pengukuran Akurat
  Widget _buildGuidanceCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tips Pengukuran Akurat (Overeem et al., 2013)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTipItem(
              '1. Letakkan ponsel di atas meja datar selama 2-3 menit tanpa disentuh agar suhu baterai menyatu dengan suhu udara ruangan.',
              theme,
            ),
            const SizedBox(height: 4),
            _buildTipItem(
              '2. Hindari mengukur saat ponsel sedang di-charge atau baru saja memainkan game berat untuk mencegah bias suhu internal.',
              theme,
            ),
            const SizedBox(height: 4),
            _buildTipItem(
              '3. Dekatkan ponsel ke stopkontak atau adaptor untuk memindai titik kebocoran hawa panas kabel (Joule Heating).',
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        height: 1.4,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }
}

/// Widget tabung termometer cairan kaca dengan animasi ketinggian merkuri
/// dan pantulan highlight 3D kaca.
class LiquidThermometerWidget extends StatelessWidget {
  final double temperatureC;
  final double minTempC;
  final double maxTempC;
  final Color liquidColor;

  const LiquidThermometerWidget({
    super.key,
    required this.temperatureC,
    this.minTempC = 0.0,
    this.maxTempC = 50.0,
    required this.liquidColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 20.0, end: temperatureC),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedTemp, child) {
        return CustomPaint(
          size: const Size(72, 220),
          painter: _LiquidThermometerPainter(
            temperatureC: animatedTemp,
            minTempC: minTempC,
            maxTempC: maxTempC,
            liquidColor: liquidColor,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        );
      },
    );
  }
}

class _LiquidThermometerPainter extends CustomPainter {
  final double temperatureC;
  final double minTempC;
  final double maxTempC;
  final Color liquidColor;
  final bool isDark;

  _LiquidThermometerPainter({
    required this.temperatureC,
    required this.minTempC,
    required this.maxTempC,
    required this.liquidColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width * 0.42;
    const stemWidth = 14.0;
    const bulbRadius = 18.0;

    final stemTop = 20.0;
    final bulbCenterY = size.height - bulbRadius - 6.0;
    final stemBottom = bulbCenterY - bulbRadius + 4.0;

    // 1. Gambar Batang Kaca (Outer Glass Stem)
    final glassStemRect = RRect.fromRectAndCorners(
      Rect.fromCenter(
        center: Offset(centerX, (stemTop + stemBottom) / 2),
        width: stemWidth + 6.0,
        height: stemBottom - stemTop,
      ),
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
    );

    final glassPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(glassStemRect, glassPaint);

    final glassBorderPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(glassStemRect, glassBorderPaint);

    // 2. Gambar Bohlam Kaca (Outer Bulb)
    canvas.drawCircle(
      Offset(centerX, bulbCenterY),
      bulbRadius + 3.0,
      glassPaint,
    );
    canvas.drawCircle(
      Offset(centerX, bulbCenterY),
      bulbRadius + 3.0,
      glassBorderPaint,
    );

    // 3. Hitung Ketinggian Cairan Berdasarkan Suhu
    final clampedTemp = temperatureC.clamp(minTempC, maxTempC);
    final frac = (clampedTemp - minTempC) / (maxTempC - minTempC);
    final liquidHeight = (stemBottom - stemTop) * frac;
    final liquidTopY = stemBottom - liquidHeight;

    // 4. Gambar Cairan di Batang (Liquid Column)
    final liquidStemRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(
        centerX - stemWidth / 2,
        liquidTopY,
        centerX + stemWidth / 2,
        stemBottom + 2.0,
      ),
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
    );

    final liquidPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          liquidColor.withValues(alpha: 0.85),
          liquidColor,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(
        centerX - stemWidth / 2,
        liquidTopY,
        centerX + stemWidth / 2,
        bulbCenterY + bulbRadius,
      ));

    canvas.drawRRect(liquidStemRect, liquidPaint);

    // 5. Gambar Cairan di Bohlam Bawah (Liquid Bulb)
    canvas.drawCircle(
      Offset(centerX, bulbCenterY),
      bulbRadius,
      liquidPaint,
    );

    // 6. Gambar Garis Skala Suhu di Sisi Kanan Batang
    final tickPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.5)
          : Colors.black.withValues(alpha: 0.4)
      ..strokeWidth = 1.2;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    const int totalDivisions = 5; // 0, 10, 20, 30, 40, 50 °C
    for (int i = 0; i <= totalDivisions; i++) {
      final t = minTempC + (maxTempC - minTempC) * (i / totalDivisions);
      final y = stemBottom - (stemBottom - stemTop) * (i / totalDivisions);

      // Gambar Garis Tick
      canvas.drawLine(
        Offset(centerX + (stemWidth / 2) + 3, y),
        Offset(centerX + (stemWidth / 2) + 10, y),
        tickPaint,
      );

      // Gambar Label Angka
      textPainter.text = TextSpan(
        text: '${t.toInt()}°',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.black.withValues(alpha: 0.6),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(centerX + (stemWidth / 2) + 13, y - textPainter.height / 2),
      );
    }

    // 7. Gambar Highlight Refleksi Kaca 3D di Sisi Kiri
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(centerX - (stemWidth / 2) + 2.5, stemTop + 6),
      Offset(centerX - (stemWidth / 2) + 2.5, stemBottom - 4),
      highlightPaint,
    );

    // Highlight pada bohlam
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(centerX, bulbCenterY),
        radius: bulbRadius - 3.0,
      ),
      -2.4,
      1.2,
      false,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidThermometerPainter oldDelegate) {
    return oldDelegate.temperatureC != temperatureC ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.isDark != isDark;
  }
}
