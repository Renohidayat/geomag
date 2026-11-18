# Panduan dan Template UAT Validasi Lapangan (User Acceptance Testing)

Dokumen ini merupakan panduan operasional standar dan lembar kerja resmi pengujian lapangan nyata (*User Acceptance Testing*) untuk aplikasi **GeoMag** sesuai spesifikasi `docs/PRD.md`.

---

## 1. Prinsip dan Standar Pengujian
1. **Kejujuran Ketidakpastian**: Magnetometer smartphone dirancang untuk orientasi digital, bukan survei eksplorasi presisi sub-nanoTesla. Anomali yang dapat diklaim valid adalah anomali yang amplitudonya melampaui lantai noise instrumen ($\ge 2 \times \text{lantai noise}$).
2. **Lingkungan Bebas Interferensi (*Quiet Site*)**: Pengujian validasi wajib dilakukan di area terbuka (lapangan hijau, hutan kota, area kampus bervegetasi) minimal:
   - 30 meter dari kendaraan bermotor atau struktur beton bertulang.
   - 50 meter dari tiang listrik tegangan tinggi / gardu transmisi.
   - Bebas dari pipa besi bawah tanah atau pagar kawat.
3. **Sterilisasi Magnetik Operator**: Surveyor dilarang mengenakan benda berbahan feromagnetik:
   - Lepaskan jam tangan mekanis/smartwatch, sabuk bergesper besi, perhiasan logam, dompet berkancing magnet, gantungan kunci, dan sepatu bersol baja.
   - Posisikan smartphone pada tripod non-magnetik (bahan kayu atau aluminium murni dengan baut kuningan/plastik) pada ketinggian konsisten (1.2 – 1.5 meter di atas permukaan tanah).

---

## 2. Rincian Protokol Pengujian Lapangan

### Protokol 1: Uji Lantai Noise Statis (*Static Noise Floor Test*)
- **Tujuan**: Menentukan noise bawaan sensor per model smartphone sebagai ambang batas anomali minimum yang sah.
- **Prosedur**:
  1. Pasang smartphone pada tripod statis di titik survei yang tenang.
  2. Buka menu **Uji Noise** di aplikasi GeoMag.
  3. Lakukan perekaman diam selama 300 detik (5 menit) pada laju sampling 50 Hz.
  4. Lakukan dua sesi: Sesi A (Layar menyala) dan Sesi B (Layar mati / standby) untuk mendeteksi interferensi layar OLED/LCD.
- **Kriteria Lulus**:
  - Simpangan baku ($\sigma$) medan total tercatat dan konsisten.
  - Lantai noise Allan deviation minimum ($\sigma_{\text{min}}$) berada di kisaran $100 - 800\text{ nT}$.

---

### Protokol 2: Uji Kebulatan & Arah Mata Angin (*Orientation Repeatability*)
- **Tujuan**: Menguji efektivitas kalibrasi ellipsoid hard-iron dan soft-iron terhadap perubahan orientasi perangkat di titik yang sama.
- **Prosedur**:
  1. Lakukan kalibrasi gerakan figur-8 (cakupan 18 sektor bola) dan terapkan profil kalibrasi aktif.
  2. Pasang smartphone di tripod.
  3. Lakukan pengukuran stasiun (30 detik per arah) menghadap 4 orientasi azimut mata angin:
     - **Utara** ($0^\circ$)
     - **Timur** ($90^\circ$)
     - **Selatan** ($180^\circ$)
     - **Barat** ($270^\circ$)
- **Kriteria Lulus**:
  - Selisih magnitudo medan total maksimum antar-keempat arah $\le 2 \times \text{lantai noise}$.
  - Simpangan baku rotasi mendekati lantai noise statis.

---

### Protokol 3: Uji Keterulangan Stasiun (*Loop / Repeat Station Test*)
- **Tujuan**: Memverifikasi stabilitas pengukuran berkala pada stasiun yang sama sepanjang hari (memeriksa efektivitas koreksi variasi harian base station).
- **Prosedur**:
  1. Tetapkan satu titik stasiun benchmark (Base/BM).
  2. Lakukan pengukuran di BM pada awal survei ($t = 0\text{ jam}$).
  3. Lakukan survei beberapa stasiun lintasan luar.
  4. Kembali dan ukur ulang titik BM pada $t = 1\text{ jam}$, $t = 2\text{ jam}$, dan akhir survei.
  5. Terapkan koreksi harian dari base station aktif.
- **Kriteria Lulus**:
  - Selisih residual stasiun berulang setelah koreksi diurnal $\le 2 \times \text{lantai noise}$.

---

### Protokol 4: Uji Konsistensi Antar-HP (*Multi-Device Profile Comparison*)
- **Tujuan**: Memastikan bentuk kurva profil anomali konsisten jika disurvei dengan dua smartphone Android berbeda merek/model.
- **Prosedur**:
  1. Buat lintasan survei sepanjang 20–50 meter dengan 10–20 stasiun patok (jarak antar-stasiun 2–5 meter).
  2. Surveyor A menyurvei lintasan menggunakan HP Model 1 (misal: Samsung Galaxy A-series).
  3. Surveyor B menyurvei lintasan yang sama persis menggunakan HP Model 2 (misal: Xiaomi Redmi Note series).
  4. Jalankan modul `RepeatabilityAnalysisService` untuk membandingkan kedua profil medan total.
- **Kriteria Lulus**:
  - Koefisien korelasi Pearson $r \ge 0.85$ (bentuk profil kongruen).
  - Minimal 90% titik memiliki selisih $\le 2 \times \text{lantai noise}$.
  - $\text{RMSE} \le 2 \times \text{lantai noise}$.

---

### Protokol 5: Uji Target Buatan (*Known Synthetic Target Test*)
- **Tujuan**: Memverifikasi daya deteksi dan kebenaran polaritas anomali dipol dari massa feromagnetik yang diketahui.
- **Prosedur**:
  1. Siapkan benda uji standar (misal: batang besi cor / silinder baja bobot 5 kg atau pipa galvanis 2 inci panjang 1 meter).
  2. Tempatkan target di tengah lintasan (Stasiun 5).
  3. Lakukan pengukuran lintasan mendekati dan menjauhi target pada jarak 0.5 m, 1.0 m, 2.0 m, dan 4.0 m.
- **Kriteria Lulus**:
  - Puncak anomali terdeteksi persis di atas target atau bergeser sesuai inklinasi lokal.
  - Polaritas sesuai anomali medan total ekuator (low di utara, high di selatan pada lintang magnetik negatif Indonesia).

---

### Protokol 6: Uji Pembanding Instrumen Geofisika (*Proton/Fluxgate Benchmark*)
*(Opsional / Jika tersedia instrumen standar industri)*
- **Tujuan**: Mengukur deviasi absolut smartphone terhadap magnetometer proton (PPM) atau cesium komersial.
- **Prosedur**:
  1. Ukur lintasan profil yang sama menggunakan Proton Magnetometer profesional.
  2. Hitung selisih RMS ($\text{RMSE}$) dan laporkan offset sistematis.
- **Kriteria Lulus**:
  - Bentuk kurva anomali berkorelasi kuat ($r \ge 0.90$).
  - Perbedaan dilaporkan secara transparan tanpa manipulasi buatan.

---

## 3. Lembar Kerja Formulir UAT Lapangan

### Informasi Umum Pengujian
| Parameter | Nilai / Keterangan |
| :--- | :--- |
| **Tanggal & Waktu** | `YYYY-MM-DD` / `HH:MM WIB` |
| **Lokasi Uji (Nama/Koordinat)** | |
| **Kondisi Cuaca & Suhu** | Cerah / Berawan / Hujan (`... °C`) |
| **Nama Surveyor** | |
| **Perangkat Utama (HP 1)** | Merk: `...`, Model: `...`, Chipset: `...`, Android: `...` |
| **Perangkat Pembanding (HP 2)**| Merk: `...`, Model: `...`, Chipset: `...`, Android: `...` |
| **Instrumen Pembanding (Jika ada)** | |

---

### Tabel Hasil Uji Protokol 1: Uji Lantai Noise Statis
| Sesi | Durasi | Sampel | $\sigma$ Medan Total ($B_{\text{obs}}$) | Lantai Noise Allan ($\sigma_{\text{min}}$) | Status (< 1000 nT) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| HP 1 - Layar Menyala | 300 s | | nT | nT | [ ] LULUS / [ ] GAGAL |
| HP 1 - Layar Mati | 300 s | | nT | nT | [ ] LULUS / [ ] GAGAL |
| HP 2 - Layar Menyala | 300 s | | nT | nT | [ ] LULUS / [ ] GAGAL |
| HP 2 - Layar Mati | 300 s | | nT | nT | [ ] LULUS / [ ] GAGAL |

---

### Tabel Hasil Uji Protokol 2: Kebulatan 4 Arah Mata Angin
| Arah Hadap | Azimut | $B_{\text{obs}}$ Terukur (nT) | Simpangan Baku Stasiun (nT) | Selisih thd Rata-rata (nT) |
| :--- | :--- | :--- | :--- | :--- |
| **Utara** | $0^\circ$ | | | |
| **Timur** | $90^\circ$ | | | |
| **Selatan** | $180^\circ$ | | | |
| **Barat** | $270^\circ$ | | | |
| **Rata-rata / Max Diff** | - | **Mean:** `... nT` | - | **Max $\Delta$:** `... nT` |
| **Batas Toleransi ($2 \times \text{Noise Floor}$)** | `... nT` | **Status:** [ ] LULUS (Max $\Delta \le \text{Tol}$) / [ ] GAGAL | | |

---

### Tabel Hasil Uji Protokol 4: Konsistensi Antar-HP (Lintasan Profil)
| No. Stasiun | Jarak (m) | Nilai HP 1 (nT) | Nilai HP 2 (nT) | Selisih $|\Delta B|$ (nT) | $\le 2\times\text{Noise}$? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| STN-001 | 0.0 | | | | [ ] Ya / [ ] Tidak |
| STN-002 | 5.0 | | | | [ ] Ya / [ ] Tidak |
| STN-003 | 10.0 | | | | [ ] Ya / [ ] Tidak |
| STN-004 | 15.0 | | | | [ ] Ya / [ ] Tidak |
| STN-005 | 20.0 | | | | [ ] Ya / [ ] Tidak |
| STN-006 | 25.0 | | | | [ ] Ya / [ ] Tidak |
| STN-007 | 30.0 | | | | [ ] Ya / [ ] Tidak |
| STN-008 | 35.0 | | | | [ ] Ya / [ ] Tidak |
| STN-009 | 40.0 | | | | [ ] Ya / [ ] Tidak |
| STN-010 | 45.0 | | | | [ ] Ya / [ ] Tidak |

**Hasil Komputasi Service Keterulangan:**
- Beda Rata-rata (Bias): `... nT`
- Root Mean Square Error (RMSE): `... nT`
- Koefisien Korelasi Pearson ($r$): `...`
- Persentase Titik Lolos Batas Toleransi: `... %`
- **Kesimpulan Status**: [ ] KONSISTEN (LULUS) / [ ] TIDAK KONSISTEN (GAGAL)

---

### Catatan Tambahan dan Tanda Tangan
**Catatan Kendala Lapangan:**
`.........................................................................................................................`
`.........................................................................................................................`

| Surveyor Pelaksana | Peninjau / Lead Geofisika |
| :---: | :---: |
| <br><br>___________________________<br>Nama & Tanda Tangan | <br><br>___________________________<br>Nama & Tanda Tangan |
