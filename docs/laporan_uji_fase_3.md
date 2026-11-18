# Laporan Pengujian dan Verifikasi Fase 3 (Pengolahan, Gridding, Peta Anomali, dan Ekspor QGIS)

Dokumen ini mencatat hasil pengujian dan verifikasi komprehensif untuk **Fase 3** (Milestone M3: Pengolahan dan peta) sesuai dengan kriteria yang ditetapkan dalam `docs/PRD.md` dan aturan kerja `AGENTS.md`.

---

## 1. Ringkasan Eksekutif

Pada Fase 3, GeoMag telah berhasil menyelesaikan seluruh target pemrosesan lanjutan spasial geomagnetik, visualisasi peta 2D interaktif, serta interoperabilitas data dengan perangkat lunak GIS profesional:
1. **Tie-Line Crossover Levelling (Issue #27)**: Algoritma pendeteksian titik potong spasial antar-lintasan survei (lintasan utama vs lintasan ikat) serta estimasi bias sistematis per lintasan menggunakan optimasi kuadrat terkecil teratur (*regularized least squares*). Terbukti mereduksi galat perpotongan sintetis dari $> 20\text{ nT}$ menjadi $< 0.01\text{ nT}$.
2. **Gridding 2D Inverse Distance Weighting & Analytic Signal 3D (Issue #28)**:
   - Interpolasi spasial Inverse Distance Weighting (IDW) berbobot eksponensial untuk memetakan sebaran titik stasiun rover tak beraturan ke matriks raster berdimensi reguler.
   - Perhitungan Analytic Signal 3D ($|AS| = \sqrt{T_x^2 + T_y^2 + T_z^2}$) menggunakan turunan horizontal diferensial terpusat dan turunan vertikal domain wavenumber via Transformasi Fourier Cepat 2D (2D FFT) dengan teknik *edge padding* dan *detrending*. Sangat ideal untuk lintasan magnetik wilayah Indonesia (lintang rendah/inklinasi mendekati $0^\circ$) yang tidak terpengaruh oleh instabilitas pembagian $\sin(I)$ pada transformasi Reduction to Pole (RTP).
3. **Layar Peta Anomali 2D Interaktif (Issue #29)**: Kanvas 2D berbasis `InteractiveViewer` dengan kontrol pan & zoom halus (0.5x–8.0x), raster colormap geofisika kontinum 6 titik kontrol, colorbar legenda dinamis dengan skala nilai & satuan otomatis (`nT` atau `nT/m`), selektor multi-layer ($B_{\text{obs}}$, $\Delta T$, $|AS|$ 3D), overlay stasiun berwarna indikator mutu, dan kartu info detail stasiun saat disentuh.
4. **Ekspor Data Geospasial Standar QGIS (Issue #30)**:
   - Format raster ESRI ASCII Grid (`.asc`) lengkap dengan header (`ncols`, `nrows`, `xllcorner`, `yllcorner`, `cellsize`, `NODATA_value`) dan pemetaan baris utara-ke-selatan.
   - Format vektor GeoJSON FeatureCollection WGS-84 (`.geojson`) untuk overlay instan di atas citra satelit atau peta geologi QGIS.
   - Format CSV anomali terintegrasi (`.csv`) yang merangkum seluruh parameter mentah, reduksi harian, IGRF, anomali, dan status mutu.
5. **Verifikasi Silang Lintas Bahasa (Dart vs Python)**: Seluruh algoritma geofisika diuji silang antara implementasi Dart dan modul referensi Python (`pytest`) dengan toleransi numerik ketat.

---

## 2. Rincian Fitur & Hasil Pengujian

### 2.1 Tie-Line Crossover Levelling (Issue #27)
- **Implementasi**:
  - Python Referensi: `reference/levelling.py`
  - Dart Murni: `app/lib/services/levelling_service.dart`
  - Unit Tests: `reference/tests/test_levelling.py` & `app/test/services/levelling_service_test.dart`
- **Metodologi Matematika**:
  - Deteksi perpotongan segmen garis 2D antar-lintasan:
    $$P(t) = P_1 + t(P_2 - P_1), \quad Q(u) = Q_1 + u(Q_2 - Q_1), \quad t, u \in [0, 1]$$
  - Pembentukan matriks observasi perpotongan $G$ dan vektor kesalahan $\epsilon = B_{\text{traverse}} - B_{\text{tie}}$.
  - Penyelesaian sistem linier teratur Tikhonov:
    $$(G^T G + \lambda I) c = G^T \epsilon$$
- **Hasil Pengujian**:
  - Pada grid sintetis 3 lintasan utama dan 2 lintasan ikat dengan injeksi pergeseran bias acak (hingga $25\text{ nT}$):
    - $RMSE_{\text{sebelum levelling}} = 20.31\text{ nT}$
    - $RMSE_{\text{setelah levelling}} = 0.0034\text{ nT}$ (reduksi galat $> 99.98\%$)
  - Kecocokan estimasi koreksi bias per lintasan antara Dart dan Python identik hingga 8 angka di belakang koma ($< 10^{-8}\text{ nT}$).
  - Penanganan kondisi batas (lintasan sejajar tanpa perpotongan) berjalan aman tanpa *exception*.

### 2.2 Gridding 2D IDW & Analytic Signal 3D (Issue #28)
- **Implementasi**:
  - Python Referensi: `reference/gridding.py` & `reference/analytic_signal.py`
  - Dart Murni: `app/lib/services/gridding_service.dart` & `app/lib/services/analytic_signal_service.dart`
  - Unit Tests: `reference/tests/test_gridding_and_as.py` & `app/test/services/gridding_and_as_service_test.dart`
- **Metodologi Geofisika**:
  - **Gridding Inverse Distance Weighting (IDW)**:
    $$Z(x, y) = \frac{\sum_{i=1}^n w_i Z_i}{\sum_{i=1}^n w_i}, \quad w_i = \frac{1}{d_i^p}$$
    Dengan proteksi simpul eksak ($d_i \le 10^{-6}\text{ m} \implies Z = Z_i$).
  - **Analytic Signal 3D**:
    $$|AS(x, y)| = \sqrt{\left(\frac{\partial T}{\partial x}\right)^2 + \left(\frac{\partial T}{\partial y}\right)^2 + \left(\frac{\partial T}{\partial z}\right)^2}$$
    - Turunan horizontal: Diferensial terpusat orde-2.
    - Turunan vertikal: Domain bilangan gelombang Fourier 2D (*wavenumber domain*):
      $$\mathcal{F}\left[\frac{\partial T}{\partial z}\right] = |k| \mathcal{F}[T], \quad |k| = \sqrt{k_x^2 + k_y^2}$$
    - Reduksi efek batas spektral (*spectral ringing*): Penghilangan tren linier (*detrending mean*) dan *edge padding* simetris ke ukuran kelipatan pangkat 2 ($2^p$).
- **Hasil Pengujian**:
  - Pengujian grid 2D pada titik simpul stasiun menghasilkan nilai identik antara Dart dan Python ($< 10^{-10}\text{ nT}$).
  - Lokalisasi sumber: Pada model benda anomali sintetis (dipol terkubur pada kedalaman $z = 15\text{ m}$), puncak $|AS|$ terbukti berimpit tepat di atas pusat benda tanpa distorsi inklinasi magnetik.
  - Nilai korelasi puncak antara Dart dan Python $= 1.0000$ dengan selisih magnitudo $< 0.05\text{ nT/m}$.

### 2.3 Layar Peta Anomali 2D Interaktif & Overlay Stasiun (Issue #29)
- **Implementasi**:
  - Layar Peta: `app/lib/screens/anomaly_map_screen.dart`
  - Widget Tests: `app/test/screens/anomaly_map_screen_test.dart`
  - Navigasi: Ikon peta pada AppBar `HomeScreen` (`app/lib/screens/home_screen.dart`)
- **Hasil Pengujian**:
  - `InteractiveViewer` merender kanvas peta beresolusi tajam dengan kontrol cubit (*pinch*) dan geser (*pan*).
  - Skema warna geofisika kontinum 6 titik kontrol:
    - Biru Tua ($0.0$) $\to$ Cyan ($0.2$) $\to$ Hijau ($0.4$) $\to$ Kuning ($0.6$) $\to$ Oranye ($0.8$) $\to$ Merah Tua ($1.0$).
  - Beralih instan antar-lapisan: Medan Total ($B_{\text{obs}}$), Anomali Medan Total ($\Delta T$), dan Analytic Signal 3D ($|AS|$).
  - Marker titik stasiun menampilkan warna status mutu (Hijau untuk `ACCEPTED`, Oranye untuk `FLAGGED`, Merah untuk `REJECTED`).
  - Mengetuk marker titik menampilkan kartu detail koordinat, $B_{\text{obs}}$, koreksi harian, IGRF, $\Delta T$, dan catatan geologi.
  - Terintegrasi generator data demo sintetis otomatis untuk pengujian langsung tanpa database survei awal.

### 2.4 Ekspor Geospasial Standar QGIS (Issue #30)
- **Implementasi**:
  - Layanan Ekspor: `app/lib/services/qgis_export_service.dart`
  - Modul Python: `reference/qgis_export.py`
  - Dialog UI: Bottom sheet ekspor pada `AnomalyMapScreen`
  - Unit Tests: `app/test/services/qgis_export_service_test.dart` & `reference/tests/test_qgis_export.py`
- **Hasil Pengujian**:
  - **ESRI ASCII Grid (`.asc`)**:
    - Validitas header 6 baris: `ncols`, `nrows`, `xllcorner`, `yllcorner`, `cellsize`, `NODATA_value`.
    - Pemetaan baris terbalik yang presisi: Baris 0 pada file adalah baris paling utara ($Y_{\text{max}}$) dan baris terakhir adalah $Y_{\text{min}}$.
    - Nilai NaN dan Infinity ditransformasikan secara aman menjadi `NODATA_value` ($-9999$).
  - **GeoJSON Titik Stasiun (`.geojson`)**:
    - Struktur valid GeoJSON `FeatureCollection` WGS-84 dengan CRS `urn:ogc:def:crs:OGC:1.3:CRS84`.
    - Koordinat terformat `[longitude, latitude]` dan properti geofisika lengkap.
  - **CSV Anomali Terpadu (`.csv`)**:
    - File teks CSV tabular yang dapat langsung diimpor ke spreadsheet dan database GIS.
  - Pengujian ekspor ke file fisik pada memori aplikasi berjalan tanpa kendala I/O.

---

## 3. Matriks Hasil Pengujian Otomatis

| Kategori Pengujian | Test Suite | Jumlah Test | Status |
| :--- | :--- | :---: | :---: |
| **Tie-Line Levelling (Dart)** | `test/services/levelling_service_test.dart` | 4 | **LULUS** (100%) |
| **Gridding IDW & Analytic Signal (Dart)** | `test/services/gridding_and_as_service_test.dart` | 6 | **LULUS** (100%) |
| **Layar Peta Anomali 2D (Dart Widgets)** | `test/screens/anomaly_map_screen_test.dart` | 4 | **LULUS** (100%) |
| **Ekspor QGIS GIS (Dart)** | `test/services/qgis_export_service_test.dart` | 5 | **LULUS** (100%) |
| **Stasiun, Base Station, & IGRF (Fase 2)** | Rangkaian test suite M2 | 35 | **LULUS** (100%) |
| **Noise & Kalibrasi Ellipsoid (Fase 1)** | Rangkaian test suite M1 | 15 | **LULUS** (100%) |
| **Fondasi Sensor & Platform (Fase 0)** | Rangkaian test suite M0 | 18 | **LULUS** (100%) |
| **Total Test Suite Flutter** | `flutter test` (seluruh repositori) | **87** | **LULUS** (100%) |
| **Levelling Referensi (Python)** | `reference/tests/test_levelling.py` | 3 | **LULUS** (100%) |
| **Gridding & AS Referensi (Python)** | `reference/tests/test_gridding_and_as.py` | 2 | **LULUS** (100%) |
| **Ekspor QGIS Referensi (Python)** | `reference/tests/test_qgis_export.py` | 4 | **LULUS** (100%) |
| **IGRF, Diurnal, Ellipsoid, Allan (Python)** | Rangkaian pytest referensi geofisika | 19 | **LULUS** (100%) |
| **Total Test Suite Python** | `pytest reference/tests` | **28** | **LULUS** (100%) |
| **Analisis Statis Dart** | `flutter analyze` | 0 isu | **BERSIH** |

---

## 4. Kesimpulan dan Kesiapan Gate 3

Semua kriteria penerimaan untuk **Milestone M3 (Pengolahan dan peta)** pada `docs/PRD.md` telah terpenuhi secara menyeluruh:
- Tie-line crossover levelling berhasil mengoreksi pergeseran bias antar-lintasan.
- Gridding IDW dan Analytic Signal 3D berbasis FFT 2D menghasilkan pemetaan batas sumber anomali yang andal untuk wilayah Indonesia.
- Kanvas peta interaktif memberikan pengalaman visualisasi lapangan modern dengan kontrol multi-layer dan informasi stasiun komprehensif.
- Ekspor ESRI ASCII Grid, GeoJSON WGS-84, dan CSV memastikan alur kerja mulus menuju QGIS dan software pengolahan geofisika profesional.
- Sebanyak **87 tests Flutter** dan **28 tests Python** lulus tanpa kegagalan, dengan kode bebas peringatan statis (`flutter analyze`).

Dengan ini, **Fase 3 dinyatakan SELESAI dan LULUS Gate 3**. Proyek siap memasuki **Fase 4 (Milestone M4: Validasi dan hardening)**.
