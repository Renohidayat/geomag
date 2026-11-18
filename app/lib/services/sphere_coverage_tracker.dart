import 'dart:math';

/// Representasi sektor pada bola orientasi 3D.
class SphereSector {
  final int id;
  final String label;
  final double minZenithRad;
  final double maxZenithRad;
  final double minAzimuthRad;
  final double maxAzimuthRad;
  int sampleCount;

  SphereSector({
    required this.id,
    required this.label,
    required this.minZenithRad,
    required this.maxZenithRad,
    required this.minAzimuthRad,
    required this.maxAzimuthRad,
    this.sampleCount = 0,
  });

  bool get isCovered => sampleCount >= 3;

  /// Memeriksa apakah vektor unit unitX, unitY, unitZ jatuh dalam sektor ini.
  bool contains(double ux, double uy, double uz) {
    // Zenith theta: 0 di kutub utara (+Z), pi di kutub selatan (-Z)
    final clampedUz = uz.clamp(-1.0, 1.0);
    final zenith = acos(clampedUz);

    if (zenith < minZenithRad || zenith > maxZenithRad) {
      return false;
    }

    // Untuk kutub, bujur tidak dibatasi
    if (minAzimuthRad == 0 && maxAzimuthRad >= 2 * pi) {
      return true;
    }

    // Azimuth phi: 0 s/d 2*pi
    var azimuth = atan2(uy, ux);
    if (azimuth < 0) azimuth += 2 * pi;

    return azimuth >= minAzimuthRad && azimuth < maxAzimuthRad;
  }
}

/// Melacak cakupan orientasi rotasi HP pada bola unit 3D.
/// Membagi bola ke dalam 18 sektor orientasi (2 kutub + 2 cincin x 8 sektor).
class SphereCoverageTracker {
  late final List<SphereSector> sectors;

  SphereCoverageTracker() {
    sectors = _createSectors();
  }

  static List<SphereSector> _createSectors() {
    final list = <SphereSector>[];
    var id = 0;

    // Kutub Atas (+Z / zenith <= 45 derajat)
    list.add(
      SphereSector(
        id: id++,
        label: '+Z Kutub Atas',
        minZenithRad: 0,
        maxZenithRad: pi / 4,
        minAzimuthRad: 0,
        maxAzimuthRad: 2 * pi,
      ),
    );

    // Cincin Belahan Atas (45 s/d 90 derajat): 8 sektor bujur (45 derajat per sektor)
    for (var i = 0; i < 8; i++) {
      list.add(
        SphereSector(
          id: id++,
          label: 'Cincin Atas $i',
          minZenithRad: pi / 4,
          maxZenithRad: pi / 2,
          minAzimuthRad: i * (pi / 4),
          maxAzimuthRad: (i + 1) * (pi / 4),
        ),
      );
    }

    // Cincin Belahan Bawah (90 s/d 135 derajat): 8 sektor bujur (45 derajat per sektor)
    for (var i = 0; i < 8; i++) {
      list.add(
        SphereSector(
          id: id++,
          label: 'Cincin Bawah $i',
          minZenithRad: pi / 2,
          maxZenithRad: 3 * pi / 4,
          minAzimuthRad: i * (pi / 4),
          maxAzimuthRad: (i + 1) * (pi / 4),
        ),
      );
    }

    // Kutub Bawah (-Z / zenith >= 135 derajat)
    list.add(
      SphereSector(
        id: id++,
        label: '-Z Kutub Bawah',
        minZenithRad: 3 * pi / 4,
        maxZenithRad: pi,
        minAzimuthRad: 0,
        maxAzimuthRad: 2 * pi,
      ),
    );

    return list;
  }

  /// Menambahkan sampel bacaan sensor mentah (mikroTesla) dan memperbarui sektor.
  int? addSample(double x, double y, double z) {
    final norm = sqrt(x * x + y * y + z * z);
    if (norm < 1e-4) return null;

    final ux = x / norm;
    final uy = y / norm;
    final uz = z / norm;

    for (final sector in sectors) {
      if (sector.contains(ux, uy, uz)) {
        sector.sampleCount++;
        return sector.id;
      }
    }
    return null;
  }

  /// Mengembalikan jumlah sektor yang telah tercover.
  int get coveredSectorCount => sectors.where((s) => s.isCovered).length;

  /// Total jumlah sektor pada bola (18 sektor).
  int get totalSectorCount => sectors.length;

  /// Persentase cakupan orientasi (0.0 s/d 100.0).
  double get coveragePercentage =>
      totalSectorCount == 0 ? 0.0 : (coveredSectorCount / totalSectorCount) * 100.0;

  /// Mengosongkan data rekaman sektor.
  void reset() {
    for (final s in sectors) {
      s.sampleCount = 0;
    }
  }
}
