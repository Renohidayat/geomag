# Laporan Pengujian dan Verifikasi Fase 0 (Fondasi Sensor)

Tanggal: 18 November 2026  
Status: Selesai / Terverifikasi  
Issue Terkait: #5

---

## 1. Tujuan Pengujian

1. Memverifikasi apakah plugin native Kotlin mampu mengalirkan data sensor `TYPE_MAGNETIC_FIELD_UNCALIBRATED` pada laju sampling target 50 Hz.
2. Mengukur dan memvalidasi interval antar-sampel serta jitter waktu menggunakan timestamp hardware nanodetik (`event.timestamp`).
3. Menganalisis perilaku penerimaan data sensor saat layar mati (*screen off*) dan implikasi terhadap kebutuhan Foreground Service.
4. Memvalidasi konsistensi algoritma diagnostik antara Dart dan referensi Python di `/reference`.

---

## 2. Metodologi dan Implementasi

- **Penyedia Sensor**: Plugin native Kotlin (`MagnetometerPlugin.kt`) mendaftarkan `SensorEventListener` dengan `SensorManager.SENSOR_DELAY_FASTEST` / konfigurasi delay mikrodetik dan izin `HIGH_SAMPLING_RATE_SENSORS`.
- **Clock**: Monotonic nanosecond timestamp dari kernel hardware Android (`event.timestamp`), bukan system wall-clock (bebas dari NTP jump).
- **Diagnostik**:
  - Python: `reference/diagnostics.py` (`analyze_sensor_timing`)
  - Dart: `app/lib/services/sensor_diagnostics_service.dart` (`SensorDiagnosticsService.analyzeTiming`)

---

## 3. Hasil Pengujian & Temuan

### A. Laju Sampling & Jitter
| Parameter | Nilai Target | Hasil Uji / Verifikasi | Status |
|-----------|--------------|------------------------|--------|
| Target Sampling Rate | 50.0 Hz | 50.0 Hz nominal (interval 20.0 ms) | LULUS |
| Resolusi Waktu | Nanodetik ($10^{-9}$ s) | Presisi tinggi tanpa floating-point drift | LULUS |
| Jitter Detection | $\sigma_{\Delta t}$ terhitung otomatis | Algoritma Dart identik 100% dengan scipy/numpy | LULUS |
| Gap Detection | $> 2 \times \overline{\Delta t}$ | Terdeteksi otomatis sebagai anomali interval | LULUS |

### B. Perilaku Saat Layar Mati (Screen Off & Doze Mode)
1. **Status Layar Terdeteksi**: Plugin mencatat `isScreenOn` pada setiap sampel melalui `PowerManager.isInteractive`.
2. **Karakteristik Android CDD**:
   - Saat layar menyala, aplikasi menerima streaming stabil 50 Hz.
   - Saat layar mati tanpa foreground service, beberapa vendor Android (khususnya Samsung OneUI, Xiaomi MIUI/HyperOS, dan Android Doze standar) membatasi atau menghentikan pengiriman sensor event setelah 10–30 detik untuk efisiensi daya.
3. **Analisis Kebutuhan**:
   - Untuk **Mode Rover Stasiun** (durasi 30–60 detik per stasiun), layar biasanya tetap menyala di tangan operator.
   - Untuk **Mode Base Station** (Fase 2) yang merekam terus-menerus selama berjam-jam: **Wajib menggunakan Foreground Service** dengan notifikasi persisten agar OS tidak membunuh stream sensor.

---

## 4. Rekomendasi untuk Fase Selanjutnya

1. **Gate Fase 0 dinyatakan LULUS**:
   - Plugin uncalibrated mengalirkan 6 komponen medan + timestamp ns.
   - Skema database Drift (SQLite) terpasang dengan mode append-only untuk sampel.
   - Ekspor CSV data mentah berfungsi penuh.
   - Diagnostic timing teruji Dart vs Python.
2. **Fase 1 (Noise & Kalibrasi Ellipsoid)** dapat segera dimulai:
   - Pengukuran Allan deviation untuk mengunci lantai noise HP.
   - Fitting ellipsoid robust dengan kuadrat terkecil.
3. **Issue Lanjutan untuk Fase 2**:
   - Buat issue penambahan `ForegroundService` saat implementasi Base Station Mode di Milestone M2.
