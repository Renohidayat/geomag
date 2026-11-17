# GeoMag

Aplikasi survei magnetik berbasis magnetometer HP Android.

## Tujuan

Menyediakan alat survei magnetik awal untuk geolog dan mahasiswa geofisika yang jujur soal ketidakpastian. Magnetometer HP hanya andal untuk anomali ratusan nT ke atas; aplikasi tidak mengklaim lebih dari lantai noise yang terukur.

## Struktur Repo

```
/app            Flutter Android app
/app/android    Plugin Kotlin (SensorManager)
/reference      Implementasi referensi Python
/config         Ambang dan parameter (thresholds.yaml)
/docs           PRD, ERD, CHANGELOG
/.github        Template PR dan issue
```

## Prasyarat

- Flutter 3.x (channel stable)
- Android SDK (min API 21)
- Python 3.10+ (untuk referensi dan test)
- HP Android dengan magnetometer uncalibrated

## Menjalankan

```bash
cd app
flutter run
```

## Pengujian

```bash
# Dart
cd app
flutter test

# Python referensi
cd reference
pytest
```

## Fase Pengembangan

| Fase | Isi |
|------|-----|
| 0 | Fondasi sensor: baca uncalibrated + timestamp ns |
| 1 | Noise dan kalibrasi ellipsoid |
| 2 | Stasiun, base station, IGRF |
| 3 | Pengolahan, peta, ekspor |
| 4 | Validasi dan hardening |
| 5 | Opsional (ML, gradiometer, iOS) |

## Lisensi

Hak cipta dilindungi.
