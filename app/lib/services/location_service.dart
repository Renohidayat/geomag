import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/weather_models.dart';

/// Layanan deteksi lokasi GPS real-time dan reverse geocoding ke wilayah administratif.
class LocationService {
  /// Memeriksa status izin dan mengambil posisi GPS aktual perangkat saat ini.
  Future<AdmLocation?> getCurrentGpsLocation() async {
    // 1. Cek apakah layanan lokasi (GPS) diaktifkan di HP
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceDisabledException();
    }

    // 2. Cek dan minta izin lokasi foreground jika belum diizinkan
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionDeniedException('Izin lokasi ditolak oleh pengguna.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionPermanentlyDeniedException(
        'Izin lokasi ditolak permanen. Buka pengaturan untuk mengaktifkan.',
      );
    }

    // 3. Ambil posisi GPS baru (fresh fix)
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );

    // 4. Reverse geocoding koordinat ke nama wilayah Indonesia
    String name = 'Lokasi Saya';
    String? district;
    String? regency;
    String province = 'Indonesia';

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // Penataan nama desa, kecamatan, kabupaten, provinsi
        name = p.subLocality?.isNotEmpty == true
            ? p.subLocality!
            : (p.locality?.isNotEmpty == true
                ? p.locality!
                : (p.subAdministrativeArea?.isNotEmpty == true
                    ? p.subAdministrativeArea!
                    : 'Lokasi Terdeteksi'));

        district = p.locality?.isNotEmpty == true ? p.locality : null;
        regency = p.subAdministrativeArea?.isNotEmpty == true ? p.subAdministrativeArea : null;
        province = p.administrativeArea?.isNotEmpty == true ? p.administrativeArea! : 'Indonesia';
      }
    } catch (_) {
      // Jika geocoding offline, gunakan koordinat ringkas
      name = 'GPS (${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)})';
    }

    return AdmLocation(
      name: name,
      district: district,
      regency: regency,
      province: province,
      latitude: position.latitude,
      longitude: position.longitude,
      isGpsLocation: true,
    );
  }
}

class LocationServiceDisabledException implements Exception {
  final String message;
  LocationServiceDisabledException([this.message = 'Layanan lokasi (GPS) di HP dinonaktifkan.']);
  @override
  String toString() => message;
}

class LocationPermissionDeniedException implements Exception {
  final String message;
  LocationPermissionDeniedException(this.message);
  @override
  String toString() => message;
}

class LocationPermissionPermanentlyDeniedException implements Exception {
  final String message;
  LocationPermissionPermanentlyDeniedException(this.message);
  @override
  String toString() => message;
}
