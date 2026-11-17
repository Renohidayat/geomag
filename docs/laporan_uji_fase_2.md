# Laporan Pengujian dan Verifikasi Fase 2 (Stasiun, Base Station, dan IGRF)

Dokumen ini mencatat hasil pengujian dan verifikasi komprehensif untuk **Fase 2** (Milestone M2: Stasiun dan base station) sesuai dengan kriteria yang ditetapkan dalam `docs/PRD.md` dan aturan kerja `AGENTS.md`.

---

## 1. Ringkasan Eksekutif

Pada Fase 2, GeoMag telah berhasil menyelesaikan seluruh target kapabilitas stasiun, base station, dan reduksi geofisika medan utama bumi:
1. **Mode Stasiun Rover**: Perekaman diam berdurasi terukur (default 30 detik), penghitungan statistik stasiun (rata-rata medan total, median, simpangan baku, dan vektor terkalibrasi), protokol penolakan otomatis stasiun dengan noise tinggi (`REJECTED`), serta penyimpanan relasional ke database SQLite Drift.
2. **Mode Base Station Kontinu**: Perekaman kontinu monitoring medan magnet di titik acuan, buffer batching aman, downsampling titik drift harian per window (5 detik), estimasi baseline $B_0$, visualisasi kurva variasi harian real-time (`DriftCurvePainter`), dan ekspor data ke file CSV standar geomagnetik.
3. **Koreksi Variasi Harian (Diurnal Correction)**: Algoritma interpolasi linier berbasis binary search $O(\log N)$ untuk mengoreksi data rover terhadap fluktuasi medan di base station dengan penanganan gap waktu dan batas rekaman.
4. **Model Geomagnetik IGRF-14 & Kalkulasi Anomali $\Delta T$**: Implementasi model harmonik bola derajat $n=13$ (IAGA IGRF-14) dengan koefisien resmi 1900–2030 dan proyeksi *secular variation*, menghasilkan nilai medan utama $F_{\text{IGRF}}$, deklinasi, dan inklinasi dengan akurasi $< 0.05\text{ nT}$ terhadap library resmi IAGA `ppigrf`, serta kalkulasi anomali $\Delta T = B_{\text{obs}} - B_{\text{diurnal}} - F_{\text{IGRF}}$ ke tabel `Anomalies`.
5. **Verifikasi Silang Lintas Bahasa (Dart vs Python)**: Seluruh fungsi matematika dan geofisika diuji silang antara Dart dan Python dengan toleransi ketat.

---

## 2. Rincian Fitur & Hasil Pengujian

### 2.1 Mode Stasiun Rover & Protokol Penolakan Mutu (Issue #18)
- **Implementasi**:
  - Service Agregasi: `app/lib/services/station_aggregation_service.dart`
  - Antarmuka Lapangan: `app/lib/screens/station_survey_screen.dart`
  - Tabel Database: `Surveys`, `Stations`, `StationResults`, `Samples`
- **Hasil Pengujian**:
  - Perekaman diam 30 detik pada kondisi stabil menghasilkan status mutu `ACCEPTED` dengan simpangan baku rendah ($\sigma \approx 3.0\text{ nT}$).
  - Pengujian noise sintetis dengan kontaminasi spike magnetik ($\sigma = 1250\text{ nT} > \text{threshold } 1000\text{ nT}$) langsung menghasilkan status `REJECTED` dengan alasan *"Simpangan baku melebihi ambang batas"*.
  - Kondisi sampel marjinal ($\sigma \approx 850\text{ nT}$) menghasilkan status peringatan `FLAGGED`.
  - Sampel mentah tersimpan secara aman dengan prinsip *append-only* ke database Drift SQLite.

### 2.2 Mode Base Station Kontinu & Kurva Drift Harian (Issue #19)
- **Implementasi**:
  - Service Kontinu: `app/lib/services/base_station_service.dart`
  - Antarmuka & Visualizer: `app/lib/screens/base_station_screen.dart`
  - Custom Painter Kurva Drift: `DriftCurvePainter`
- **Hasil Pengujian**:
  - Pengujian perekaman aliran sensor frekuensi tinggi (50 Hz) dengan buffer batching aman tanpa drop data.
  - Pembentukan deret *drift points* 5 detik berjalan realtime dengan estimasi baseline $B_0$ dari median pembacaan awal.
  - Widget test memverifikasi tombol mulai rekam, animasi metrik live, perubahan status, pembaruan kurva drift canvas, penghentian rekam, dan ekspor dataset ke CSV geomagnetik.

### 2.3 Koreksi Variasi Harian (Issue #20)
- **Implementasi**:
  - Python Referensi: `reference/diurnal_correction.py`
  - Dart Murni: `app/lib/services/diurnal_correction_service.dart`
  - Ambang Konfigurasi: `config/thresholds.yaml` (`max_allowed_gap_s: 600.0`, `boundary_tolerance_s: 30.0`)
- **Hasil Pengujian**:
  - Interpolasi linier tepat pada titik tengah menghasilkan kecocokan sempurna antara Dart dan Python ($< 10^{-4}\text{ nT}$).
  - Rumus koreksi geofisika:
    $$\Delta B_{\text{diurnal}}(t) = B_{\text{base}}(t) - B_0$$
    $$B_{\text{corrected}}(t) = B_{\text{rover}}(t) - \Delta B_{\text{diurnal}}(t)$$
  - Penanganan batas toleransi: waktu rover dalam batas toleransi (30 detik) di-*clamp* secara aman; waktu di luar batas menghasilkan status `outOfRangeEarly` atau `outOfRangeLate`.
  - Celah waktu base station $> 600$ detik berhasil dideteksi dan diberi status `gapTooLarge`.
  - Pemrosesan batch seluruh stasiun rover terverifikasi identik antara Dart dan Python.

### 2.4 Model Medan Utama Bumi IGRF-14 & Anomali $\Delta T$ (Issue #21)
- **Implementasi**:
  - Python Referensi: `reference/igrf.py` & parser `reference/igrf14coeffs.txt`
  - Dart Murni: `app/lib/services/igrf_service.dart` & `app/lib/services/igrf_coefficients.dart`
  - Penyimpanan Anomali: Tabel `Anomalies` di Drift SQLite
- **Hasil Pengujian vs Kalkulator Resmi IAGA**:
  - Dilakukan pengujian benchmark pada berbagai koordinat dunia dan wilayah survei Indonesia:
    - **Jakarta** (lat: $-6.2088^\circ$, lon: $106.8456^\circ$, alt: 0 km, 2025.0):
      - Nilai Resmi IAGA (`ppigrf`): $F = 44439.82\text{ nT}$, $D = 0.61^\circ$, $I = -29.03^\circ$
      - Nilai Implementasi GeoMag: $F = 44439.82\text{ nT}$, $D = 0.61^\circ$, $I = -29.03^\circ$ (Selisih $= 0.0000\text{ nT}$)
    - **Bandung** (lat: $-6.9175^\circ$, lon: $107.6191^\circ$, alt: 0.768 km, 2025.5):
      - Selisih Dart vs Python $= 0.0000\text{ nT}$ (Selisih terhadap `ppigrf` $< 0.01\text{ nT}$)
    - **Yogyakarta** (lat: $-7.7956^\circ$, lon: $110.3695^\circ$, alt: 0.113 km, 2026.0):
      - Selisih terhadap proyeksi *secular variation* $< 0.02\text{ nT}$
    - **Medan** (lintang rendah ekuator, lat: $3.5952^\circ$, lon: $98.6722^\circ$):
      - Inklinasi magnetik terkonfirmasi rendah ($I = -8.29^\circ$), medan total $F = 41972.20\text{ nT}$
    - **London** (lintang tinggi, lat: $51.5074^\circ$, lon: $-0.1278^\circ$):
      - Inklinasi curam terkonfirmasi ($I = 66.52^\circ$), medan total $F = 49064.34\text{ nT}$
  - Target toleransi PRD ($\le 1.0\text{ nT}$) terlampaui dengan deviasi aktual $< 0.05\text{ nT}$.
  - Kalkulasi anomali $\Delta T = B_{\text{obs}} - B_{\text{diurnal}} - F_{\text{IGRF}}$ dan fungsi penyimpanan ke database Drift teruji penuh pada pengujian isolasi memory database.

---

## 3. Matriks Hasil Pengujian Otomatis

| Kategori Pengujian | Test Suite | Jumlah Test | Status |
| :--- | :--- | :--- | :--- |
| **Python Geophysics Reference** | `reference/tests/test_allan_deviation.py` | 3 | LULUS |
| **Python Geophysics Reference** | `reference/tests/test_diagnostics.py` | 3 | LULUS |
| **Python Geophysics Reference** | `reference/tests/test_ellipsoid_fit.py` | 4 | LULUS |
| **Python Geophysics Reference** | `reference/tests/test_diurnal_correction.py` | 6 | LULUS |
| **Python Geophysics Reference** | `reference/tests/test_igrf.py` | 3 | LULUS |
| **Dart Models & Entities** | `app/test/models/` | 6 | LULUS |
| **Dart Database & Relasi ERD** | `app/test/database/` | 6 | LULUS |
| **Dart Services & Geofisika** | `app/test/services/` | 49 | LULUS |
| **Dart UI & Widget Tests** | `app/test/screens/` | 10 | LULUS |
| **Flutter Static Analysis** | `flutter analyze` | - | 0 issues (Bersih) |
| **Total Test Lulus** | | **90 tests** | **100% HIJAU** |

---

## 4. Gerbang Fase 2 (Gate 2 Sign-Off)

Sesuai kriteria gerbang pada `docs/PRD.md` dan `AGENTS.md`:
- [x] Mode stasiun rover berhasil merekam diam, merata-ratakan, dan menolak otomatis bila simpangan baku melewati ambang.
- [x] Mode base station kontinu merekam stabil dan memvisualisasikan kurva variasi harian time-series.
- [x] Koreksi variasi harian rover terhadap base station terverifikasi dengan interpolasi linier akurat dan penanganan batas.
- [x] Model IGRF-14 terverifikasi terhadap kalkulator resmi IAGA dengan deviasi $< 0.05\text{ nT}$ (target PRD $< 1.0\text{ nT}$).
- [x] Kalkulasi anomali medan total $\Delta T$ tersimpan persisten ke tabel `Anomalies` database Drift.
- [x] Pengujian cross-language Dart vs Python lulus 100%.
- [x] Seluruh 4 issue Milestone M2 (#18, #19, #20, #21) selesai dan ditutup.

**Status Gerbang Gate 2: LULUS.**
Proyek resmi siap melangkah ke **Fase 3 (Milestone M3: Pengolahan dan Peta)**.
