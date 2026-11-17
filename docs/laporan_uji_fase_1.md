# Laporan Pengujian dan Verifikasi Fase 1 (Noise dan Kalibrasi Ellipsoid)

Dokumen ini mencatat hasil pengujian komprehensif untuk **Fase 1** (Milestone M1) sesuai dengan kriteria yang ditetapkan dalam `docs/PRD.md` dan aturan kerja `AGENTS.md`.

---

## 1. Ringkasan Eksekutif

Pada Fase 1, sistem GeoMag berhasil mengimplementasikan dan memverifikasi algoritma geofisika inti untuk:
1. **Allan Deviation Analysis**: Menentukan lantai noise empiris perangkat smartphone saat diam dan estimasi waktu integrasi optimal ($\tau$).
2. **Kalibrasi Ellipsoid Robust**: Mengoreksi efek *hard iron* (vektor offset $b$) dan *soft iron* (matriks 3x3 $A$) menggunakan metode kuadrat terkecil robust (IRLS Huber weighting) yang tahan terhadap kontaminasi data liar/outlier saat HP diputar.
3. **Pelacak Cakupan Orientasi Bola 3D**: Antarmuka visual yang membagi bola orientasi menjadi 18 sektor untuk memastikan HP diputar merata ke seluruh kuadran 3D sebelum kalibrasi dieksekusi.
4. **Verifikasi Silang Lintas Bahasa (Dart vs Python)**: Seluruh algoritma geofisika diuji silang antara implementasi Dart dan modul referensi Python dengan hasil selaras ($< 0.01\%$ deviasi).

---

## 2. Rincian Fitur & Pengujian

### 2.1 Allan Deviation & Noise Floor Testing (Issue #11)
- **Implementasi**:
  - Python: `reference/allan_deviation.py`
  - Dart: `app/lib/services/allan_deviation_service.dart`
  - Layar Interaktif: `app/lib/screens/noise_test_screen.dart`
- **Hasil Pengujian**:
  - Pengujian white noise sintetis $\sigma = 2.0$ nT menunjukkan penurunan Allan deviation sesuai karakteristik integrasi rata-rata $1/\sqrt{N}$.
  - Deviasi komparasi numerik Dart vs Python: $< 0.01\%$.
  - Penyimpanan nilai lantai noise terukur otomatis masuk ke tabel `Devices` profil HP di Drift SQLite.

### 2.2 Kalibrasi Ellipsoid Robust (Issue #12)
- **Implementasi**:
  - Python: `reference/ellipsoid_fit.py`
  - Dart: `app/lib/services/ellipsoid_calibration_service.dart`
- **Metode Matematika**:
  - Penyelesaian sistem persamaan kuadrik kuadrat terkecil 9x9 $(D^T W D) p = D^T W Y$ via eliminasi Gauss partial pivoting.
  - Dekomposisi nilai eigen simetris $3 \times 3$ via algoritma Jacobi eigenvalue untuk mendapatkan $M^{1/2}$ dan matriks koreksi $A = B_{ref} \cdot M^{1/2}$.
  - Pembobotan robust Huber (IRLS) dan pre-filtering berbasis MAD untuk menolak outlier.
- **Hasil Pengujian**:
  - Bola Sempurna ($B_{ref} = 45.0\ \mu T$): Offset $b \approx [0, 0, 0]$, matriks $A \approx I_3$, residu RMSE $< 1.0$ nT.
  - Ellipsoid Sintetis (Offset $[12.5, -8.2, 5.0]\ \mu T$, Skala $[1.10, 0.95, 1.05]$): Offset terpulihkan dengan akurasi $< 0.1\ \mu T$, simpangan baku sebelum kalibrasi $> 1000$ nT turun menjadi $< 10$ nT sesudah kalibrasi.
  - Outlier Rejection: 5 titik anomali ekstrem ($150 - 200\ \mu T$) berhasil ditolak secara otomatis tanpa merusak estimasi geometri ellipsoid.

### 2.3 Antarmuka Panduan Cakupan Orientasi Bola (Issue #13)
- **Implementasi**:
  - Logika Sektor: `app/lib/services/sphere_coverage_tracker.dart`
  - Visual 3D & Layar: `app/lib/screens/calibration_screen.dart`
- **Fitur Antarmuka**:
  - Pembagian bola ke dalam 18 sektor ruang 3D (2 kutub polar + 2 cincin bujur 8 sektor).
  - Indikator persentase cakupan real-time saat HP diputar di udara.
  - Pointer posisi vektor magnetik aktif real-time dengan efek visual kedalaman bola (depan vs belakang).
  - Tombol aksi cerdas yang hanya aktif ketika sampel $\ge \text{min\_samples}$ dan cakupan sektor memadai ($\ge 50\%$).
  - Dialog hasil metrik kalibrasi (RMSE residu nT, $\sigma_{before}$ vs $\sigma_{after}$, hard iron offset) dan tombol simpan ke database `CalibrationProfiles`.

---

## 3. Matriks Hasil Pengujian Otomatis

| Kategori Pengujian | Test Suite | Jumlah Test | Status |
| :--- | :--- | :--- | :--- |
| **Python Geophysics Reference** | `reference/tests/test_allan_deviation.py` | 3 | LULUS |
| **Python Geophysics Reference** | `reference/tests/test_diagnostics.py` | 3 | LULUS |
| **Python Geophysics Reference** | `reference/tests/test_ellipsoid_fit.py` | 4 | LULUS |
| **Dart / Flutter Unit Tests** | `app/test/models/` | 6 | LULUS |
| **Dart / Flutter Unit Tests** | `app/test/database/` | 6 | LULUS |
| **Dart / Flutter Unit Tests** | `app/test/services/` | 26 | LULUS |
| **Dart / Flutter Widget Tests** | `app/test/screens/` | 6 | LULUS |
| **Flutter Static Analysis** | `flutter analyze` | - | 0 issues (Bersih) |
| **Total Test Lulus** | | **54 tests** | **100% HIJAU** |

---

## 4. Gerbang Fase 1 (Gate 1 Sign-Off)

Sesuai kriteria gerbang pada `docs/PRD.md`:
- [x] Lantai noise terukur via Allan deviation.
- [x] Kalibrasi ellipsoid menghasilkan residu terukur dan simpangan baku magnitudo turun drastis sesudah koreksi.
- [x] Panduan bola visual memberikan konfirmasi cakupan orientasi 3D.
- [x] Database Drift menyimpan parameter kalibrasi secara persisten.
- [x] Seluruh kriteria Milestone M1 selesai dan ditutup.

**Status Gerbang Gate 1: LULUS.**
Proyek siap melanjutkan ke **Fase 2 (Milestone M2: Stasiun dan Base Station)**.
