# Changelog

Semua perubahan penting dicatat di sini.

## [Belum dirilis]

### Ditambahkan
- Implementasi estimasi lantai noise dan Allan deviation (`AllanDeviationService` di Dart & `reference/allan_deviation.py` di Python) (#11)
- Layar interaktif `NoiseTestScreen` dengan protokol uji perangkat diam dan penyimpanan lantai noise ke profil perangkat (#11)
- Pengujian cross-language Dart vs Python untuk algoritma Allan deviation (#11)
- Implementasi `SensorDiagnosticsService` (Dart) dan `reference/diagnostics.py` (Python) untuk analisis laju sampling nyata, jitter, dan deteksi gap (#5)
- Pengujian cross-language Dart vs Python untuk diagnostik timing sensor (#5)
- Laporan pengujian dan verifikasi Fase 0 di `docs/laporan_uji_fase_0.md` (#5)
- Implementasi `CsvExportService` untuk format dan ekspor file CSV sampel magnetometer mentah (#4)
- Implementasi `RecordingSessionService` dengan batch buffering untuk perekaman frekuensi tinggi dan jaminan zero data loss (#4)
- Integrasi penyimpanan otomatis sesi rekam ke SQLite dan tombol ekspor CSV pada `HomeScreen` (#4)
- Unit test format CSV, pipeline ekspor file, dan lifecycle batch session (#4)
- Sampel dataset pengujian di `test/fixtures/sample_station_data.csv` (#4)
- Penyempurnaan antarmuka real-time dengan timer durasi rekam, indikator visual kestabilan sinyal $\sigma$, dan peringatan pengisian daya (#3)
- Widget test interaktif untuk verifikasi alur mulai/berhenti rekam dan visualisasi stream sampel (#3)
- Implementasi penyimpanan lokal SQLite via Drift sesuai ERD (#2)
- Skema lengkap: Devices, CalibrationProfiles, Surveys, Stations, Samples, StationResults, Anomalies (#2)
- Aturan append-only pada tabel Samples untuk integritas data mentah (#2)
- Unit test database komprehensif menguji relasi foreign keys, batch insert, dan query helper (#2)
- Plugin Kotlin native untuk membaca `TYPE_MAGNETIC_FIELD_UNCALIBRATED` via `EventChannel` dengan fallback ke `TYPE_MAGNETIC_FIELD` (#1)
- Timestamp nanodetik (`event.timestamp`) pada setiap sampel data (#1)
- Model data `MagnetometerSample` dan `SensorInfo` di Flutter (#1)
- `MagnetometerService` dengan perhitungan laju sampling nyata, jitter, dan interval (#1)
- Layar utama `HomeScreen` yang menampilkan data real-time, status sensor, suhu baterai, status charging, dan laju sampling (#1)
- Izin `HIGH_SAMPLING_RATE_SENSORS` di AndroidManifest (#1)
- Unit test & widget test untuk model, service, dan antarmuka (#1)
- Struktur repo awal dan dokumen perencanaan (PRD, ERD, Rencana Aplikasi)
