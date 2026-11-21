import 'package:geocoding/geocoding.dart';
import '../models/weather_models.dart';

/// Layanan direktori wilayah administratif Indonesia (Kabupaten/Kota, Kecamatan, & Desa)
/// serta pencarian pelosok/dusun via Geocoding.
class Adm4Service {
  /// Dataset wilayah administratif (Kabupaten/Kota & Kecamatan populer/lengkap Indonesia).
  /// Disusun berdasarkan basis data kode wilayah Kemendagri / BMKG.
  static const List<AdmLocation> defaultLocations = [
    // Jawa Barat - Sumedang (Spesifik rujukan pengguna)
    AdmLocation(
      name: 'Cimalaka',
      district: 'Kec. Cimalaka',
      regency: 'Kab. Sumedang',
      province: 'Jawa Barat',
      latitude: -6.8122,
      longitude: 107.9482,
    ),
    AdmLocation(
      name: 'Sumedang Utara',
      district: 'Kec. Sumedang Utara',
      regency: 'Kab. Sumedang',
      province: 'Jawa Barat',
      latitude: -6.8375,
      longitude: 107.9211,
      adm4Code: '32.11.01.2001',
    ),
    AdmLocation(
      name: 'Sumedang Selatan',
      district: 'Kec. Sumedang Selatan',
      regency: 'Kab. Sumedang',
      province: 'Jawa Barat',
      latitude: -6.8580,
      longitude: 107.9250,
      adm4Code: '32.11.02.2001',
    ),
    AdmLocation(
      name: 'Jatinangor',
      district: 'Kec. Jatinangor',
      regency: 'Kab. Sumedang',
      province: 'Jawa Barat',
      latitude: -6.9312,
      longitude: 107.7738,
      adm4Code: '32.11.18.2001',
    ),
    AdmLocation(
      name: 'Wado',
      district: 'Kec. Wado',
      regency: 'Kab. Sumedang',
      province: 'Jawa Barat',
      latitude: -6.9974,
      longitude: 108.1520,
      adm4Code: '32.11.01.2001',
    ),
    AdmLocation(
      name: 'Tanjungsari',
      district: 'Kec. Tanjungsari',
      regency: 'Kab. Sumedang',
      province: 'Jawa Barat',
      latitude: -6.9038,
      longitude: 107.8031,
      adm4Code: '32.11.19.2001',
    ),
    AdmLocation(
      name: 'Paseh',
      district: 'Kec. Paseh',
      regency: 'Kab. Sumedang',
      province: 'Jawa Barat',
      latitude: -6.8042,
      longitude: 107.9863,
      adm4Code: '32.11.15.2001',
    ),
    AdmLocation(
      name: 'Conggeang',
      district: 'Kec. Conggeang',
      regency: 'Kab. Sumedang',
      province: 'Jawa Barat',
      latitude: -6.7621,
      longitude: 108.0125,
      adm4Code: '32.11.16.2001',
    ),

    // Kota Bandung & Sekitarnya
    AdmLocation(
      name: 'Coblong',
      district: 'Kec. Coblong',
      regency: 'Kota Bandung',
      province: 'Jawa Barat',
      latitude: -6.8836,
      longitude: 107.6163,
      adm4Code: '32.73.10.1001',
    ),
    AdmLocation(
      name: 'Sukasari',
      district: 'Kec. Sukasari',
      regency: 'Kota Bandung',
      province: 'Jawa Barat',
      latitude: -6.8687,
      longitude: 107.5888,
      adm4Code: '32.73.01.1001',
    ),
    AdmLocation(
      name: 'Lengkong',
      district: 'Kec. Lengkong',
      regency: 'Kota Bandung',
      province: 'Jawa Barat',
      latitude: -6.9298,
      longitude: 107.6234,
      adm4Code: '32.73.06.1001',
    ),
    AdmLocation(
      name: 'Lembang',
      district: 'Kec. Lembang',
      regency: 'Kab. Bandung Barat',
      province: 'Jawa Barat',
      latitude: -6.8167,
      longitude: 107.6167,
      adm4Code: '32.17.01.2001',
    ),
    AdmLocation(
      name: 'Soreang',
      district: 'Kec. Soreang',
      regency: 'Kab. Bandung',
      province: 'Jawa Barat',
      latitude: -7.0253,
      longitude: 107.5186,
      adm4Code: '32.04.05.2001',
    ),

    // DKI Jakarta & Bodetabek
    AdmLocation(
      name: 'Gambir',
      district: 'Kec. Gambir',
      regency: 'Kota Jakarta Pusat',
      province: 'DKI Jakarta',
      latitude: -6.1754,
      longitude: 106.8272,
      adm4Code: '31.71.01.1001',
    ),
    AdmLocation(
      name: 'Kebayoran Baru',
      district: 'Kec. Kebayoran Baru',
      regency: 'Kota Jakarta Selatan',
      province: 'DKI Jakarta',
      latitude: -6.2435,
      longitude: 106.7997,
      adm4Code: '31.74.01.1001',
    ),
    AdmLocation(
      name: 'Menteng',
      district: 'Kec. Menteng',
      regency: 'Kota Jakarta Pusat',
      province: 'DKI Jakarta',
      latitude: -6.1963,
      longitude: 106.8335,
      adm4Code: '31.71.06.1001',
    ),
    AdmLocation(
      name: 'Bogor Tengah',
      district: 'Kec. Bogor Tengah',
      regency: 'Kota Bogor',
      province: 'Jawa Barat',
      latitude: -6.5971,
      longitude: 106.7996,
      adm4Code: '32.71.03.1001',
    ),
    AdmLocation(
      name: 'Cibinong',
      district: 'Kec. Cibinong',
      regency: 'Kab. Bogor',
      province: 'Jawa Barat',
      latitude: -6.4817,
      longitude: 106.8539,
      adm4Code: '32.01.01.2001',
    ),
    AdmLocation(
      name: 'Pancoran Mas',
      district: 'Kec. Pancoran Mas',
      regency: 'Kota Depok',
      province: 'Jawa Barat',
      latitude: -6.3986,
      longitude: 106.8041,
      adm4Code: '32.76.01.1001',
    ),
    AdmLocation(
      name: 'Bekasi Selatan',
      district: 'Kec. Bekasi Selatan',
      regency: 'Kota Bekasi',
      province: 'Jawa Barat',
      latitude: -6.2452,
      longitude: 106.9934,
      adm4Code: '32.75.04.1001',
    ),
    AdmLocation(
      name: 'Serpong',
      district: 'Kec. Serpong',
      regency: 'Kota Tangerang Selatan',
      province: 'Banten',
      latitude: -6.3149,
      longitude: 106.6669,
      adm4Code: '36.74.01.1001',
    ),

    // Jawa Tengah & DIY
    AdmLocation(
      name: 'Semarang Tengah',
      district: 'Kec. Semarang Tengah',
      regency: 'Kota Semarang',
      province: 'Jawa Tengah',
      latitude: -6.9819,
      longitude: 110.4208,
      adm4Code: '33.74.01.1001',
    ),
    AdmLocation(
      name: 'Banjarsari',
      district: 'Kec. Banjarsari',
      regency: 'Kota Surakarta (Solo)',
      province: 'Jawa Tengah',
      latitude: -7.5562,
      longitude: 110.8228,
      adm4Code: '33.72.04.1001',
    ),
    AdmLocation(
      name: 'Danurejan (Malioboro)',
      district: 'Kec. Danurejan',
      regency: 'Kota Yogyakarta',
      province: 'DI Yogyakarta',
      latitude: -7.7956,
      longitude: 110.3695,
      adm4Code: '34.71.04.1001',
    ),
    AdmLocation(
      name: 'Depok Sleman',
      district: 'Kec. Depok',
      regency: 'Kab. Sleman',
      province: 'DI Yogyakarta',
      latitude: -7.7656,
      longitude: 110.4092,
      adm4Code: '34.04.07.2001',
    ),

    // Jawa Timur
    AdmLocation(
      name: 'Tegalsari',
      district: 'Kec. Tegalsari',
      regency: 'Kota Surabaya',
      province: 'Jawa Timur',
      latitude: -7.2654,
      longitude: 112.7378,
      adm4Code: '35.78.07.1001',
    ),
    AdmLocation(
      name: 'Klojen',
      district: 'Kec. Klojen',
      regency: 'Kota Malang',
      province: 'Jawa Timur',
      latitude: -7.9797,
      longitude: 112.6304,
      adm4Code: '35.73.02.1001',
    ),

    // Luar Jawa Utama
    AdmLocation(
      name: 'Medan Kota',
      district: 'Kec. Medan Kota',
      regency: 'Kota Medan',
      province: 'Sumatera Utara',
      latitude: 3.5852,
      longitude: 98.6756,
      adm4Code: '12.71.02.1001',
    ),
    AdmLocation(
      name: 'Padang Barat',
      district: 'Kec. Padang Barat',
      regency: 'Kota Padang',
      province: 'Sumatera Barat',
      latitude: -0.9471,
      longitude: 100.3543,
      adm4Code: '13.71.02.1001',
    ),
    AdmLocation(
      name: 'Ujung Pandang',
      district: 'Kec. Ujung Pandang',
      regency: 'Kota Makassar',
      province: 'Sulawesi Selatan',
      latitude: -5.1477,
      longitude: 119.4327,
      adm4Code: '73.71.04.1001',
    ),
    AdmLocation(
      name: 'Denpasar Selatan',
      district: 'Kec. Denpasar Selatan',
      regency: 'Kota Denpasar',
      province: 'Bali',
      latitude: -8.6705,
      longitude: 115.2126,
      adm4Code: '51.71.01.1001',
    ),
  ];

  /// Mencari lokasi administratif dari query pengguna (pencarian lokal instan).
  List<AdmLocation> searchLocal(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return defaultLocations;

    return defaultLocations.where((loc) {
      final name = loc.name.toLowerCase();
      final district = loc.district?.toLowerCase() ?? '';
      final regency = loc.regency?.toLowerCase() ?? '';
      final prov = loc.province.toLowerCase();

      return name.contains(cleanQuery) ||
          district.contains(cleanQuery) ||
          regency.contains(cleanQuery) ||
          prov.contains(cleanQuery);
    }).toList();
  }

  /// Mencari lokasi pelosok / dusun / desa secara daring via Geocoding
  /// jika pengguna mencari nama tempat spesifik yang belum ada di daftar lokal.
  Future<List<AdmLocation>> searchOnline(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return defaultLocations;

    // 1. Cek hasil lokal terlebih dahulu
    final localMatches = searchLocal(cleanQuery);
    if (localMatches.isNotEmpty) {
      return localMatches;
    }

    // 2. Jika tidak ada di lokal, cari secara daring via Geocoding
    try {
      final searchQuery = cleanQuery.toLowerCase().contains('indonesia')
          ? cleanQuery
          : '$cleanQuery, Indonesia';

      final locations = await locationFromAddress(searchQuery);
      final results = <AdmLocation>[];

      for (final l in locations.take(5)) {
        try {
          final placemarks = await placemarkFromCoordinates(l.latitude, l.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final name = p.subLocality?.isNotEmpty == true
                ? p.subLocality!
                : (p.locality?.isNotEmpty == true
                    ? p.locality!
                    : cleanQuery);

            results.add(
              AdmLocation(
                name: name,
                district: p.locality,
                regency: p.subAdministrativeArea,
                province: p.administrativeArea ?? 'Indonesia',
                latitude: l.latitude,
                longitude: l.longitude,
              ),
            );
          }
        } catch (_) {
          results.add(
            AdmLocation(
              name: cleanQuery,
              province: 'Indonesia',
              latitude: l.latitude,
              longitude: l.longitude,
            ),
          );
        }
      }

      if (results.isNotEmpty) return results;
    } catch (_) {}

    return localMatches;
  }
}
