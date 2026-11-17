# Changelog

Semua perubahan penting dicatat di sini.

## [Belum dirilis]

### Ditambahkan
- Plugin Kotlin native untuk membaca `TYPE_MAGNETIC_FIELD_UNCALIBRATED` via `EventChannel` dengan fallback ke `TYPE_MAGNETIC_FIELD` (#1)
- Timestamp nanodetik (`event.timestamp`) pada setiap sampel data (#1)
- Model data `MagnetometerSample` dan `SensorInfo` di Flutter (#1)
- `MagnetometerService` dengan perhitungan laju sampling nyata, jitter, dan interval (#1)
- Layar utama `HomeScreen` yang menampilkan data real-time, status sensor, suhu baterai, status charging, dan laju sampling (#1)
- Izin `HIGH_SAMPLING_RATE_SENSORS` di AndroidManifest (#1)
- Unit test & widget test untuk model, service, dan antarmuka (#1)
- Struktur repo awal dan dokumen perencanaan (PRD, ERD, Rencana Aplikasi)
