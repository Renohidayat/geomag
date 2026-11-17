# Rencana Aplikasi Magnetometer Geofisika (Flutter Android)

Nov 17, 2026 · @ss

Aplikasi ini layak dibuat dengan Flutter untuk Android, tetapi magnetometer HP hanya cukup untuk anomali magnetik ratusan nT ke atas. Akurasi tinggi datang dari kalibrasi, protokol lapangan, dan koreksi geofisika, bukan dari sensornya.

## Batas hardware HP

Resolusi sensor HP sekitar 0,15 µT (150 nT), tetapi noise nyata di lapangan terukur 200–500 nT. Anomali di bawah beberapa ratus nT tidak bisa dideteksi dengan andal. Angka Android di bawah adalah batas minimum yang dijamin, bukan performa tiap HP.

| Parameter | Nilai | Sumber |
| --- | --- | --- |
| Resolusi minimum yang diwajibkan Android | ≤ 0,6 µT (600 nT) | [Android CDD 7.3](https://android.googlesource.com/platform/compatibility/cdd/+/0ff19f83dde5a5577ff201a7cdf8c8c96a8d2b67/7_hardware-compatibility/7_3_sensors.md) |
| Simpangan baku noise (3 detik, laju tertinggi) | wajib ≤ 1,5 µT, dianjurkan ≤ 0,5 µT | [Android CDD 7.3](https://android.googlesource.com/platform/compatibility/cdd/+/refs/tags/android-security-11.0.0_r54/7_hardware-compatibility/7_3_sensors.md) |
| Rentang ukur per sumbu | ± 900 µT | [Android CDD 7.3](https://android.googlesource.com/platform/compatibility/cdd/+/bf601acd33be70653d2f4b03d1cf0436dccb561a/7_hardware-compatibility/7_3_sensors.md) |
| Offset hard iron | wajib < 700 µT, dianjurkan < 200 µT | [Android CDD 7.3](https://android.googlesource.com/platform/compatibility/cdd/+/bf601acd33be70653d2f4b03d1cf0436dccb561a/7_hardware-compatibility/7_3_sensors.md) |
| Chip umum AK09918 | 16-bit, 0,15 µT/LSB, ± 4912 µT | [Datasheet AKM](https://static.chipdip.ru/lib/829/DOC031829574.pdf) |
| Laju lapor | wajib ≥ 10 Hz, dianjurkan ≥ 50 Hz; di atas 200 Hz perlu izin HIGH\_SAMPLING\_RATE\_SENSORS | [CDD](https://android.googlesource.com/platform/compatibility/cdd/+/android-cts-9.0_r3/7_hardware-compatibility/7_3_sensors.md), [AOSP](https://gitlab.e.foundation/e/os/android_frameworks_base/-/commit/857efd19a413356c102d5b5451f94c301cf4db6b) |
| Noise digitisasi nominal | ± 150 nT, tidak Gaussian, tidak turun dengan rata-rata √N | [Odenwald 2018, IEEE Access](https://doaj.org/article/f68397fa7d8e4bb585eee244a49a5c68) |
| Noise saat survei jalan kaki (Galaxy Note 4, AK09911C) | ± 500 nT; makin cepat sampling, makin buruk | [Geophysical applications of magnetic sensors in smartphones](https://pubs.geoscienceworld.org/seg/tle/article/39/5/312/584642/Geophysical-applications-of-magnetic-sensors-in-smartphones) |
| Fluktuasi total field iPhone 3GS | ± 200 nT antar titik; perlu rata-rata 25 detik | [Overhauser vs iPhone, AGU 2012](https://ui.adsabs.harvard.edu/abs/2012AGUFMNS13B1617O/abstract) |

Dua konsekuensi untuk desain. Pertama, Android wajib menerapkan koreksi hard iron dan soft iron otomatis pada data standar, sehingga data itu bisa melompat saat OS mengubah kalibrasi. Aplikasi sebaiknya membaca sensor uncalibrated (dianjurkan, tidak dijamin ada di semua HP) dan mengkalibrasi sendiri. Kedua, rata-rata memang menurunkan noise, tetapi ada batas bawah akibat digitisasi, jadi lantai noise setiap model HP harus diukur sendiri di Fase 1.

## Riset terdahulu

Studi yang saya temukan sepakat: HP berhasil memetakan anomali kuat (timbunan besi, pipa, dike magnetit) bila data dirata-rata dan dikoreksi, tetapi gagal pada anomali di bawah ratusan nT. Dalam pencarian saya belum ada studi yang menggabungkan kalibrasi terintegrasi, base station, dan koreksi geofisika dalam satu aplikasi; itu celah untuk proyek Anda.

| Studi | Perangkat dan pembanding | Temuan utama |
| --- | --- | --- |
| [Geophysical applications of magnetic sensors in smartphones](https://pubs.geoscienceworld.org/seg/tle/article/39/5/312/584642/Geophysical-applications-of-magnetic-sensors-in-smartphones) (SEG, The Leading Edge, 2020) | Galaxy Note 4 (AK09911C) vs cesium Geometrics G858, pipa terkubur dan landfill | Di landfill hasilnya sebanding dengan G858. Pipa tidak terdeteksi di luar radius sekitar 1 m. Noise ± 500 nT; akurasi turun saat laju sampling naik. |
| [Overhauser vs iPhone 3GS](https://ui.adsabs.harvard.edu/abs/2012AGUFMNS13B1617O/abstract) (AGU, 2012) | iPhone 3GS (Hall) vs Overhauser GEM, Pyramid Lake | Tidak berkorelasi akurat untuk anomali < 200 nT. Total field bervariasi ± 200 nT; dirata-rata 25 detik. |
| [Small and Low-Cost Magnetic Sensors for Geophysical Exploration](https://pmc.ncbi.nlm.nih.gov/articles/PMC11548162/) (PMC, 2024) | Sensor AMR dan Hall iPhone vs cesium MFAM, area 40 × 28 m, profil jarak 1 m | Untuk anomali ratusan nT, data vektor yang diubah ke total field mendekati sensor skalar profesional. |
| [Abu Marwat, Mesir](https://journals.ekb.eg/article_352386_c51eb644feb812a1bd163fd4a2200c95.pdf) (Assiut Univ. Bulletin, 2024) | Physics Toolbox vs proton precession; peta TMI, RTP, spektrum daya radial | Kedalaman sumber dangkal/dalam: ≈ 4 m dan 9 m (proton) vs 5 m dan 13 m (HP). Dangkal cocok, dalam melenceng. |
| [Eraky dkk., Assiut](https://aunj.journals.ekb.eg/article_254586_cc904e3df6d6689ea57fc031d83a4c83.pdf) (2022) | Physics Toolbox, iPhone 7 Plus, jaring 0,5 m, filter Butterworth | Memetakan geometri dan kedalaman pipa; penulis menyarankan kalibrasi dengan magnetometer ilmiah. |
| [CrowdMag](https://ciresblogs.colorado.edu/crowdmag/?p=47) (NOAA/CIRES) | Ribuan HP, ML kalibrasi per perangkat, stacking | Dike besi (magnetit) di Colorado terpetakan setelah data di-stack dan dihaluskan. Korelasi dengan observatorium USGS Deadhorse pada hari variasi > 1000 nT ([poster](https://insidecires.colorado.edu/rendezvous/uploads/Rendezvous_2023_4487_1683821152.pdf)). |
| [SmartMagDL](https://www.sciencedirect.com/science/article/pii/S0098300425001906) (Fisher dkk., 2026) | Data HP jarang, deep learning super-resolution, simulasi 30 × 30 m | Peta lebih akurat daripada interpolasi klasik; baru teruji pada data simulasi dan dalam ruangan. |
| [Odenwald 2018](https://theoryandpractice.citizenscienceassociation.org/articles/10.5334/cstp.158) | iPhone 6s, Galaxy Note 5, Galaxy S8 | Noise didominasi white noise sekitar ± 200 nT; badai magnetik (≈ 1000 nT) masih bisa terlihat. |
| [Magneview](https://ejournal.kahuripan.ac.id/index.php/TECNOSCIENZA/article/download/935/665) (Indonesia) | Aplikasi Android + web service, polarisasi Z/H | Contoh lokal: data sensor HP dikirim ke layanan web untuk diproses. |

Pelajaran praktis: rata-rata dan stacking wajib, kalibrasi per perangkat wajib, dan klaim kedalaman dari HP harus diperlakukan sebagai estimasi kasar.

## Sumber error dan cara menekannya

Sepuluh sumber error ini paling menentukan mutu data. Hampir semuanya bisa ditekan lewat aplikasi atau prosedur lapangan; satu-satunya yang tidak bisa dihilangkan adalah lantai noise digitisasi sensor.

| Sumber error | Efek pada data | Mitigasi di aplikasi | Mitigasi di lapangan |
| --- | --- | --- | --- |
| Noise dan digitisasi sensor | ± 150–500 nT per sampel | Rata-rata per stasiun 30–60 detik, filter median/Hampel, ukur lantai noise tiap model HP (Allan deviation) | Diam di titik saat merekam |
| Hard iron internal (magnet speaker, casing, holder) | Offset konstan pada tiap sumbu | Kalibrasi ellipsoid, simpan parameter per perangkat | Lepas casing atau holder bermagnet, pakai dudukan non-magnetik |
| Soft iron (pelindung EMI, sekrup, baterai) | Skala dan sumbu terdistorsi, sehingga magnitudo medan berubah menurut orientasi | Kalibrasi matriks 3 × 3, cek bentuk bola setelah kalibrasi | Kalibrasi jauh dari struktur besi |
| Arus listrik di dalam HP (layar, charging, radio) | Medan berubah menurut beban; kalibrasi hanya valid selama arus konstan ([paten kompas HP](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/8880373)) | Kunci kecerahan dan mode kerja, catat status charging dan layar di tiap sampel | Jangan mengisi daya saat mengukur; kalibrasi dan survei dalam kondisi yang sama |
| Benda ferromagnetik sekitar (kunci, jam, sepatu besi, kendaraan, pagar, kabel listrik) | Lonjakan dan offset mendadak | Deteksi lonjakan, tandai stasiun mencurigakan, minta ukur ulang | Operator melepas benda logam; catat objek di sekitar titik |
| Drift suhu | Offset bergeser pelan; sensor magneto-inductive murah menunjukkan ketergantungan suhu linear ([studi lima magnetometer](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC13468621/)); untuk sensor HP perlu diuji | Catat suhu baterai sebagai proksi, pengukuran ulang titik acuan tiap 30–60 menit | Lindungi HP dari sinar matahari langsung |
| Orientasi dan error heading | Skala dan sumbu sensor tiga sumbu tidak sempurna, sehingga total field berubah menurut arah pegang | Pakai total field (magnitudo vektor, tidak peka rotasi), kalibrasi skala memakai total field dari IGRF | Orientasi tetap pada tripod; ukur empat arah (U, T, S, B) lalu rata-rata |
| Variasi harian dan badai magnetik | Medan berubah menurut waktu; wilayah ekuator dipengaruhi equatorial electrojet ([Margiono dkk. 2021](https://gi.copernicus.org/articles/10/169/2021/)) | Koreksi base station, cek indeks Kp sebelum survei | Survei di jam tenang; HP kedua diam di titik acuan |
| Posisi GPS HP | Galat GNSS HP beberapa meter, setara atau lebih besar daripada jarak stasiun ([Sensors 2017](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5677268/)) | Dukungan GNSS eksternal via Bluetooth (NMEA) di fase lanjut, simpan akurasi tiap titik | Jaring lokal dengan pita ukur untuk survei detail; GPS hanya untuk rekognisi |
| Laju sampling tidak stabil dan jitter | Interval sampel tidak teratur; Android tidak menjamin laju yang diminta ([sensors\_plus](https://pub.dev/documentation/sensors_plus/4.0.1)) | Baca sensor lewat kode native Kotlin, simpan timestamp event tiap sampel, resampling bila perlu | Uji laju nyata tiap HP sebelum survei |

Catatan: mitigasi di kolom aplikasi yang tidak bersumber (Allan deviation, empat arah, suhu baterai) adalah praktik umum pengukuran magnetometer yang saya usulkan, bukan temuan dari studi di atas; semuanya harus diuji di Fase 1.

## Kalibrasi sensor

Kalibrasi ellipsoid mengoreksi hard iron, soft iron, skala, dan ketidaktegaklurusan sumbu. Hasilnya hanya sebaik data putar yang mencakup semua orientasi, dan hanya berlaku selama kondisi arus di dalam HP sama dengan saat kalibrasi.

Modelnya: bacaan mentah digeser oleh vektor hard iron **b** lalu dikalikan matriks 3 × 3 **A** (soft iron, skala, sumbu miring). Setelah koreksi, titik data yang tadinya membentuk ellipsoid bergeser dan berubah menjadi bola ([Tesla Labs](https://teslabs.com/articles/magnetometer-calibration)).

```latex
\mathbf{B}_{cal} = \mathbf{A}\,(\mathbf{B}_{raw} - \mathbf{b}), \qquad \lVert \mathbf{B}_{cal} \rVert \approx B_{ref}
```

Langkah di aplikasi:

1. Baca sensor uncalibrated: tiga nilai pertama adalah medan tanpa kalibrasi hard iron, tiga nilai berikutnya estimasi bias dari Android ([dokumentasi Android](https://developer.android.com/develop/sensors-and-location/sensors/sensors_position.md.txt)). Simpan keduanya.
2. Pandu pengguna memutar HP dengan indikator cakupan bola orientasi, bukan sekadar "gerakan angka 8", sampai semua sektor terisi.
3. Cocokkan ellipsoid dengan kuadrat terkecil; buang outlier dengan fit yang robust ([contoh pendekatan paten](https://patents.google.com/patent/US10151805); perbandingan metode di [De Gruyter 2024](https://www.degruyterbrill.com/document/doi/10.1515/jag-2024-0055/pdf)).
4. Tentukan nilai acuan B\_ref dari total field IGRF/WMM di lokasi dan tanggal kalibrasi. Kalibrasi hanya di tempat terbuka tanpa logam, karena anomali lokal merusak B\_ref.
5. Hitung kualitas: simpangan baku magnitudo setelah koreksi harus mendekati lantai noise model HP itu (kriteria penerimaan yang saya usulkan, nilainya ditetapkan di Fase 1).
6. Simpan parameter per perangkat beserta tanggal, suhu, dan kondisi (casing, layar). Tandai kedaluwarsa bila pengecekan titik acuan melenceng dari ambang.
7. Verifikasi di lapangan: ukur satu titik tenang dalam empat arah; selisih total field antar arah harus kecil.

Karena survei memakai selisih terhadap titik acuan, kesalahan skala global tidak terlalu merusak anomali relatif. Yang merusak adalah magnitudo yang berubah menurut orientasi, dan itulah yang dikoreksi langkah 3.

## Pipeline koreksi geofisika

Urutan standarnya: bersihkan data, koreksi variasi harian, kurangi medan utama bumi (IGRF), levelling, lalu grid dan filter. Untuk Indonesia yang berlintang magnetik rendah, jangan mengandalkan reduction to pole (RTP) standar.

```latex
\Delta T = B_{obs} - F_{IGRF}(\varphi,\lambda,h,t) - \left(B_{base}(t) - \overline{B_{base}}\right)
```

1. **Total field per sampel.** Hitung magnitudo vektor terkalibrasi. Besaran ini tidak peka rotasi, sehingga orientasi HP tidak mengubah hasil ([PMC 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11548162/)).
2. **Pembersihan dan rata-rata.** Buang lonjakan (median/Hampel) dan sampel saat HP bergerak, lalu hasilkan satu nilai per stasiun beserta simpangan baku dan jumlah sampel sebagai indikator mutu.
3. **Variasi harian.** Kurangi variasi HP base station yang diam dan direkam bersamaan, diinterpolasi pada waktu tiap titik ([contoh prosedur USGS](https://pubs.usgs.gov/of/2002/ofr-02-452/t_data_proc.html), [BGS](https://earthwise.bgs.ac.uk/index.php/OR/14/014_Part_3:_Data_processing)). Tanpa base station, ukur ulang titik acuan tiap 30–60 menit dan koreksi drift sebagai fungsi waktu berorde rendah ([Yarger dkk., KGS 1977](https://www.kgs.ku.edu/Publications/OFR/1977/KGSOFR1977-20.pdf)).
4. **Medan utama IGRF.** Kurangi IGRF di posisi dan waktu aktual tiap titik; IGRF-14 dirilis akhir 2024 ([BGS](https://www.bgs.ac.uk/news/update-to-essential-scientific-reference-maps-reveals-new-movement-of-the-earths-magnetic-field/)) dan WMM2025 tersedia gratis ([NOAA NCEI](https://www.ncei.noaa.gov/news/world-magnetic-model-2025-released)). Validasi implementasi aplikasi terhadap kalkulator resmi.
5. **Levelling.** Minimalkan selisih di perpotongan profil dan tie-line, lalu micro-levelling ([BGS](https://earthwise.bgs.ac.uk/index.php/OR/14/014_Part_3:_Data_processing)); ada juga metode tanpa tie-line ([White dan Beamish 2015](https://core.ac.uk/download/33451088.pdf)).
6. **Gridding.** Kriging atau minimum curvature, dengan ukuran sel sekitar seperlima jarak profil (praktik [USGS](https://pubs.usgs.gov/of/2002/ofr-02-452/t_data_proc.html)). BMKG memakai collocated cokriging untuk model regional Indonesia ([Ahadi dkk. 2023](https://link.springer.com/content/pdf/10.1134/S001679322260062X.pdf)).
7. **Filter dan transformasi.** Pemisahan regional-residual (filter Butterworth dipakai [Eraky dkk.](https://aunj.journals.ekb.eg/article_254586_cc904e3df6d6689ea57fc031d83a4c83.pdf)), upward continuation, turunan vertikal, dan analytic signal.
8. **Interpretasi.** Estimasi kedalaman lewat spektrum daya atau model maju, selalu dilabeli estimasi. Studi Abu Marwat menunjukkan sumber dalam bisa meleset beberapa meter.
9. **Ekspor.** CSV mentah dan terkoreksi, serta format yang bisa dibuka di QGIS, Oasis montaj, atau Python (Harmonica, SimPEG).

### Catatan lintang rendah di Indonesia

Inklinasi magnetik Indonesia rendah (perkiraan saya: mendekati 0° di utara sampai sekitar −30° di selatan; verifikasi dengan IGRF). Pada lintang rendah anomali menjadi asimetris dan melemah. RTP standar tidak stabil dan menghasilkan artefak sejajar deklinasi, terutama dalam 20° dari ekuator ([Rajagopalan 2003](https://publish.csiro.au/ex/ASEG2003ab136)). Analytic signal 3D tidak banyak bergantung pada arah magnetisasi ([MacLeod dkk. 1993](https://publish.csiro.au/EG/EG993679)), dan RTP yang distabilkan dengan regularisasi tersedia ([Li dan Oldenburg 2001](https://acnpsearch.tweb-dev.unibo.it/singlejournalindex/81330915)). Rekomendasi: Fase 1–3 cukup peta total field, analytic signal, dan turunan; RTP stabil menunggu Fase 4.

Soal base station: BMKG mengoperasikan observatorium geomagnet di Tuntungan, Tangerang, Pelabuhan Ratu, Tondano, Kupang, dan Papua ([BMKG](https://www.bmkg.go.id/berita/utama/fgd-geomagnetic-magnet-bumi-untuk-kehidupan)). Namun kualitas data sering kurang baik dan belum bergabung di INTERMAGNET ([Margiono dkk. 2021](https://gi.copernicus.org/articles/10/169/2021/)), jadi jangan menggantungkan koreksi pada data itu. HP base station sendiri lebih aman.

## Arsitektur aplikasi

&#91;embedded content: arsitektur aplikasi · 4 lapisan, ditambah referensi Python dan HP base station\]

Data mengalir dari sensor ke plugin Kotlin, lalu ke penyimpanan, kalibrasi, koreksi geofisika, antarmuka, dan ekspor. HP base station merekam variasi harian untuk koreksi, dan skrip Python (garis putus-putus) menguji setiap algoritma Dart.

Kenapa sensor dibaca lewat Kotlin: Android tidak menjamin laju yang diminta dari plugin Flutter, dan aplikasi perlu sensor uncalibrated beserta timestamp tiap event. Saya belum memverifikasi apakah sensors\_plus mengekspos sensor uncalibrated. Layanan foreground belum terbukti perlu; Fase 0 menguji apakah sensor tetap melapor saat layar mati.

## Protokol survei lapangan

Protokol ini membuat data bisa dibandingkan antar hari dan antar operator. Angka durasi dan jarak di bawah adalah usulan awal yang ditetapkan ulang setelah uji noise di Fase 1.

### Sebelum survei

- Kalibrasi di tempat terbuka tanpa logam. Catat suhu dan kondisi HP: casing dilepas, kecerahan terkunci, tidak sedang diisi daya.
- Pilih hari dengan aktivitas geomagnet tenang (cek indeks Kp).
- Pasang HP base station di titik tenang, jauh dari jalan, kabel, dan pagar besi. Rekam terus sepanjang survei dengan jam yang disinkronkan.
- Rencanakan profil tegak lurus perkiraan arah struktur. Aturan praktis: jarak profil dan stasiun tidak lebih besar dari kedalaman target. Studi pipa terkubur memakai jarak 0,5–1 m dan hanya mendeteksi target sampai radius sekitar 1 m.
- Operator melepas kunci, jam, ikat pinggang, dan sepatu ber-pelindung baja bila memungkinkan.

### Di setiap stasiun

- Pegang HP pada tripod atau tongkat non-magnetik, tinggi sensor sama dan tercatat, orientasi tetap.
- Diam 30–60 detik. Studi iPhone merata-ratakan 25 detik. Aplikasi menolak stasiun bila simpangan baku melewati ambang dan meminta ulang.
- Bila memungkinkan, ulangi dalam empat arah lalu rata-rata.
- Catat benda di sekitar (pagar, kendaraan, kabel) dan posisi: GPS untuk rekognisi, jaring lokal terukur untuk survei detail.
- Tiap 30–60 menit kembali ke titik acuan untuk memeriksa drift.

### Setelah survei

- Ulangi pengecekan kalibrasi; bila parameter bergeser jauh, tandai seluruh sesi.
- Ekspor data mentah, metadata, parameter kalibrasi, dan laporan mutu otomatis.
- Ulangi sekitar 5–10% stasiun di hari lain untuk mengukur keterulangan (usulan).

## Roadmap fase dan gate

&#91;embedded content: roadmap · 6 fase, 5 gate\]

Setiap gate harus lulus sebelum fase berikutnya dimulai; angka ambangnya ditetapkan dari data Fase 1. Estimasi durasi belum saya isi karena ukuran tim dan luas area survei belum diketahui (lihat Pertanyaan terbuka).

## Validasi dan kriteria keberhasilan

Aplikasi disebut akurat hanya jika lolos uji yang bisa diulang orang lain. Semua ambang di bawah adalah usulan; angkanya dikunci setelah data lantai noise Fase 1 tersedia.

| Uji | Cara | Kriteria lulus (usulan) |
| --- | --- | --- |
| Lantai noise per HP | Rekam diam 30–60 menit di tempat tenang, hitung Allan deviation | Nilai tercatat per model; menjadi dasar ambang anomali minimum yang boleh diklaim |
| Kebulatan setelah kalibrasi | Putar HP ke semua orientasi, hitung simpangan baku magnitudo | Mendekati lantai noise model itu |
| Keterulangan stasiun | Ukur ulang 5–10% titik di hari berbeda | Selisih tidak lebih dari dua kali lantai noise |
| Konsistensi antar HP | Tiga model HP mengukur profil yang sama | Bentuk profil sama; selisih amplitudo anomali dilaporkan |
| Target buatan | Pelat atau batang baja pada kedalaman dan posisi diketahui | Lokasi benar, amplitudo sesuai model maju sederhana, jarak deteksi tercatat |
| Pembanding instrumen | Survei yang sama dengan proton, Overhauser, atau cesium (pinjam dari kampus atau instansi geologi) | Beda RMS dilaporkan; studi terdahulu sebanding pada anomali kuat |
| Implementasi IGRF | Bandingkan keluaran aplikasi dengan kalkulator resmi NOAA/BGS di banyak titik | Selisih sangat kecil (target ≤ 1 nT) |
| Tren harian | Bandingkan rekaman base station dengan data observatorium atau CrowdMag pada hari aktif | Pola harian cocok |

Laporan mutu tiap survei harus otomatis: lantai noise yang dipakai, jumlah stasiun ditolak, residu levelling, dan anomali terkecil yang masih bisa diklaim.

## Panduan Antigravity

Taruh aturan proyek di AGENTS.md pada root repositori, lalu jalankan satu prompt per fase. Antigravity memuat AGENTS.md otomatis dan selalu aktif tanpa frontmatter. Hanya file di folder proyek dan folder induknya yang dimuat, subfolder tidak. Satu file dipotong di atas 24 KB ([dokumentasi rules Antigravity](https://antigravity.google/docs/rules.md)). Aturan ini mencegah agent mengarang algoritma geofisika.

Isi AGENTS.md yang saya usulkan:

```markdown
# Proyek GeoMag (Flutter Android)

## Tujuan
Aplikasi survei magnetik memakai magnetometer HP Android. Prioritas: ketepatan data dan keterbukaan soal ketidakpastian, bukan jumlah fitur.

## Aturan keras
- Baca sensor lewat kode native Kotlin (SensorManager), bukan plugin Flutter. Pakai TYPE_MAGNETIC_FIELD_UNCALIBRATED. Simpan event.timestamp (nanodetik) pada setiap sampel.
- Jangan pernah membuang data mentah. Data terkoreksi selalu turunan dari data mentah + parameter kalibrasi yang tersimpan.
- Setiap algoritma geofisika (kalibrasi ellipsoid, IGRF, levelling, analytic signal) wajib punya implementasi referensi Python di /reference dan test yang membandingkan hasil Dart dengan Python.
- Jangan mengarang rumus atau koefisien. Bila ragu, tulis TODO dan tanya.
- Satuan: mikroTesla untuk sensor, nanoTesla untuk anomali. Tulis satuan di nama variabel.
- Ambang angka dibaca dari config/thresholds.yaml, diisi dari hasil uji Fase 1. Jangan hard-code.
- UI selalu menampilkan simpangan baku dan jumlah sampel di samping tiap nilai.
- Bahasa UI: Indonesia.

## Struktur
/app (Flutter), /app/android (plugin Kotlin), /reference (Python), /docs

## Definisi selesai
Test lulus, flutter analyze bersih, ada catatan di docs/CHANGELOG.md.
```

Prompt per fase (tempel satu per satu; minta agent menulis rencana dulu, tinjau, baru eksekusi):

| Fase | Prompt untuk agent |
| --- | --- |
| 0 | Buat proyek Flutter Android dengan plugin Kotlin yang mengalirkan sensor magnetometer uncalibrated lewat EventChannel, lengkap dengan timestamp nanodetik. Simpan data mentah ke CSV dan tampilkan laju sampling nyata serta jitter. |
| 1 | Tambahkan modul uji noise (rekam diam, hitung Allan deviation) dan modul kalibrasi ellipsoid dengan indikator cakupan orientasi. Tulis dulu versi referensi Python, lalu Dart, dan bandingkan hasilnya. Tampilkan simpangan baku magnitudo sebelum dan sesudah kalibrasi. |
| 2 | Buat mode stasiun: rekam diam, rata-rata, tolak stasiun bila simpangan baku melewati ambang. Buat mode base station dengan sinkron waktu dan koreksi variasi harian. Implementasikan IGRF dan validasi terhadap kalkulator resmi. |
| 3 | Buat pengolahan: levelling, gridding (kriging atau minimum curvature), peta anomali, analytic signal, dan ekspor ke format yang dibuka QGIS. Semua dengan test terhadap data sintetis. |
| 4 | Tambahkan laporan mutu otomatis, perbandingan multi-HP, dan dukungan GNSS eksternal lewat Bluetooth NMEA. Siapkan RTP stabil untuk lintang rendah sebagai opsi. |

Fase 5 (kalibrasi berbasis machine learning per perangkat, gradiometer dua HP, iOS) baru dikerjakan setelah Fase 4 lolos validasi lapangan.

## PRD (kebutuhan produk, versi awal)

Ditulis dengan asumsi yang belum Anda konfirmasi; ubah setelah pertanyaan terbuka terjawab. Prinsip produk: data yang jujur soal ketidakpastian lebih penting daripada banyaknya fitur.

**Pengguna:** geolog atau mahasiswa geofisika yang melakukan survei magnetik awal di lapangan memakai HP Android. **Masalah:** aplikasi EMF yang ada hanya menampilkan angka mentah, tanpa kalibrasi, koreksi, atau peta anomali. **Di luar cakupan awal:** iOS, interpretasi otomatis kedalaman sebagai fakta, dan klaim setara instrumen proton atau cesium.

| Kebutuhan | Prioritas | Fase |
| --- | --- | --- |
| Merekam magnetometer uncalibrated dengan timestamp nanodetik dan menyimpan data mentah | Wajib | 0 |
| Uji lantai noise per HP dan menampilkan hasilnya | Wajib | 1 |
| Kalibrasi ellipsoid dengan panduan cakupan orientasi dan nilai kualitas | Wajib | 1 |
| Mode stasiun: rekam diam, rata-rata, tolak otomatis bila terlalu noisy | Wajib | 2 |
| Mode base station dan koreksi variasi harian | Wajib | 2 |
| Pengurangan IGRF per titik dan waktu | Wajib | 2 |
| Peta anomali, levelling, gridding, analytic signal | Wajib | 3 |
| Ekspor CSV dan format yang dibuka QGIS | Wajib | 3 |
| Laporan mutu otomatis tiap survei | Wajib | 4 |
| GNSS eksternal via Bluetooth, RTP stabil | Sebaiknya | 4 |
| Kalibrasi berbasis ML, gradiometer dua HP, iOS | Nanti | 5 |

Keberhasilan produk diukur dengan tabel kriteria di bagian Validasi, bukan dengan jumlah unduhan.

## ERD (struktur data, versi awal)

Satu survei punya banyak stasiun, satu stasiun punya banyak sampel, dan survei rover menunjuk ke survei base station yang direkam bersamaan. Parameter kalibrasi disimpan per perangkat dan dicatat pada setiap sampel supaya koreksi bisa diulang dari data mentah.

| Entitas | Kolom utama | Relasi |
| --- | --- | --- |
| Device | id, model, versi Android, chip magnetometer, lantai noise (nT) | 1 Device punya banyak CalibrationProfile dan banyak Survey |
| CalibrationProfile | id, device\_id, waktu, vektor hard iron b (3), matriks A (9), suhu, casing terpasang, residu (nT), berlaku sampai | Dipakai oleh banyak Sample |
| Survey | id, device\_id, nama, tanggal, mode (rover atau base), catatan, base\_survey\_id | 1 Survey punya banyak Station; survei rover menunjuk survei base |
| Station | id, survey\_id, urutan, lat, lon, akurasi GPS, x dan y lokal, tinggi sensor, arah pegang, catatan sekitar | 1 Station punya banyak Sample dan satu StationResult |
| Sample | id, station\_id, calibration\_id, timestamp (ns), nilai mentah x y z, bias OS x y z, suhu baterai, status charging, status layar | Milik satu Station |
| StationResult | station\_id, rata-rata total field (nT), simpangan baku, jumlah sampel, diterima atau ditolak, alasan | Satu per Station |
| Anomaly | station\_id, F\_IGRF (nT), koreksi harian (nT), anomali ΔT (nT) | Satu per Station, dihitung ulang dari data mentah |

Aturan data: tabel Sample tidak pernah diubah atau dihapus; Anomaly dan StationResult adalah turunan yang boleh dihitung ulang.

## Pertanyaan terbuka

Jawaban Anda mengubah ambang, jarak profil, dan prioritas fase.

- Maksud "planing flow erp": saya menafsirkannya sebagai alur perencanaan pengembangan aplikasi. Bila yang dimaksud ERP (sistem manajemen data perusahaan), bagian arsitektur perlu ditambah.
- Batuan atau target apa yang dicari (basalt, andesit, ultramafik, bijih besi), pada kedalaman berapa, dan seluas apa areanya?
- Ukuran "sangat akurat" menurut pemberi tugas: berapa nT yang harus terdeteksi?
- HP apa yang akan dipakai (merek, model, chip magnetometer) dan versi Android minimum?
- Apakah ada akses ke magnetometer pembanding (proton, Overhauser, cesium) untuk validasi?
- Apakah pengolahan harus jalan offline di HP, atau cukup ekspor lalu olah di komputer?

## Sumber

Diambil dari ringkasan hasil pencarian per 17 November 2026, kecuali halaman aturan Antigravity yang dibuka penuh. Baca makalah aslinya sebelum dikutip di laporan resmi.

- [Android CDD 7.3 Sensors](https://android.googlesource.com/platform/compatibility/cdd/+/refs/tags/android-security-11.0.0_r54/7_hardware-compatibility/7_3_sensors.md); [versi dengan rentang ukur dan hard iron](https://android.googlesource.com/platform/compatibility/cdd/+/bf601acd33be70653d2f4b03d1cf0436dccb561a/7_hardware-compatibility/7_3_sensors.md)
- [Dokumentasi sensor posisi Android](https://developer.android.com/develop/sensors-and-location/sensors/sensors_position.md.txt)
- [Datasheet AK09918](https://static.chipdip.ru/lib/829/DOC031829574.pdf)
- [Geophysical applications of magnetic sensors in smartphones (SEG 2020)](https://pubs.geoscienceworld.org/seg/tle/article/39/5/312/584642/Geophysical-applications-of-magnetic-sensors-in-smartphones)
- [Overhauser vs iPhone 3GS (AGU 2012)](https://ui.adsabs.harvard.edu/abs/2012AGUFMNS13B1617O/abstract)
- [Small and Low-Cost Magnetic Sensors (PMC 2024)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11548162/)
- [Abu Marwat, Mesir](https://journals.ekb.eg/article_352386_c51eb644feb812a1bd163fd4a2200c95.pdf); [Eraky dkk., Assiut](https://aunj.journals.ekb.eg/article_254586_cc904e3df6d6689ea57fc031d83a4c83.pdf)
- [CrowdMag, Iron Dike](https://ciresblogs.colorado.edu/crowdmag/?p=47); [poster CIRES](https://insidecires.colorado.edu/rendezvous/uploads/Rendezvous_2023_4487_1683821152.pdf)
- [SmartMagDL](https://www.sciencedirect.com/science/article/pii/S0098300425001906)
- [Odenwald, citizen science](https://theoryandpractice.citizenscienceassociation.org/articles/10.5334/cstp.158); [IEEE Access 2018](https://doaj.org/article/f68397fa7d8e4bb585eee244a49a5c68)
- [Magneview (Kahuripan)](https://ejournal.kahuripan.ac.id/index.php/TECNOSCIENZA/article/download/935/665)
- [Tesla Labs, kalibrasi magnetometer](https://teslabs.com/articles/magnetometer-calibration); [paten kalibrasi US10151805](https://patents.google.com/patent/US10151805); [De Gruyter 2024](https://www.degruyterbrill.com/document/doi/10.1515/jag-2024-0055/pdf)
- [USGS, pemrosesan aeromagnetik](https://pubs.usgs.gov/of/2002/ofr-02-452/t_data_proc.html); [BGS OR/14/014](https://earthwise.bgs.ac.uk/index.php/OR/14/014_Part_3:_Data_processing); [Yarger dkk., KGS 1977](https://www.kgs.ku.edu/Publications/OFR/1977/KGSOFR1977-20.pdf); [White dan Beamish 2015](https://core.ac.uk/download/33451088.pdf)
- [IGRF-14, BGS](https://www.bgs.ac.uk/news/update-to-essential-scientific-reference-maps-reveals-new-movement-of-the-earths-magnetic-field/); [WMM2025, NOAA NCEI](https://www.ncei.noaa.gov/news/world-magnetic-model-2025-released)
- [Rajagopalan 2003](https://publish.csiro.au/ex/ASEG2003ab136); [MacLeod dkk. 1993](https://publish.csiro.au/EG/EG993679); [Li dan Oldenburg 2001](https://acnpsearch.tweb-dev.unibo.it/singlejournalindex/81330915)
- [Margiono dkk. 2021, observatorium Indonesia](https://gi.copernicus.org/articles/10/169/2021/); [Ahadi dkk. 2023](https://link.springer.com/content/pdf/10.1134/S001679322260062X.pdf); [BMKG](https://www.bmkg.go.id/berita/utama/fgd-geomagnetic-magnet-bumi-untuk-kehidupan)
- [sensors\_plus](https://pub.dev/documentation/sensors_plus/4.0.1); [studi lima magnetometer](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC13468621/); [Sensors 2017, georeferensi HP](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5677268/)
- [Dokumentasi rules Antigravity](https://antigravity.google/docs/rules.md)
