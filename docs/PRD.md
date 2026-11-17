# PRD GeoMag (versi awal)

Status: draf. Asumsi di bawah belum dikonfirmasi pemberi tugas; ubah setelah pertanyaan terbuka terjawab.

## Prinsip produk
Data yang jujur soal ketidakpastian lebih penting daripada banyaknya fitur. Magnetometer HP hanya andal untuk anomali ratusan nT ke atas; aplikasi tidak boleh mengklaim lebih dari lantai noise yang terukur.

## Pengguna dan masalah
- Pengguna: geolog atau mahasiswa geofisika yang melakukan survei magnetik awal di lapangan memakai HP Android.
- Masalah: aplikasi EMF yang ada hanya menampilkan angka mentah, tanpa kalibrasi, koreksi, atau peta anomali.

## Di luar cakupan awal
iOS, interpretasi otomatis kedalaman sebagai fakta, dan klaim setara instrumen proton atau cesium.

## Kebutuhan

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

## Kriteria keberhasilan (usulan; ambang dikunci setelah data Fase 1)

| Uji | Kriteria lulus |
| --- | --- |
| Lantai noise per HP | Tercatat per model; dasar ambang anomali minimum yang boleh diklaim |
| Kebulatan setelah kalibrasi | Simpangan baku magnitudo mendekati lantai noise |
| Keterulangan stasiun | Selisih tidak lebih dari dua kali lantai noise |
| Konsistensi antar HP | Bentuk profil sama; selisih amplitudo dilaporkan |
| Target buatan | Lokasi benar dan jarak deteksi tercatat |
| Pembanding instrumen | Beda RMS dilaporkan |
| Implementasi IGRF | Selisih terhadap kalkulator resmi sangat kecil (target 1 nT atau kurang) |

## Fase dan gate
Fase 0 fondasi sensor, 1 noise dan kalibrasi, 2 stasiun dan base station, 3 pengolahan dan peta, 4 validasi dan hardening, 5 opsional. Fase berikutnya dibuka hanya setelah gate fase sebelumnya lulus.

## Pertanyaan terbuka
- Batuan atau target apa, kedalaman berapa, seluas apa area survei?
- Berapa nT yang harus terdeteksi menurut pemberi tugas?
- HP, chip magnetometer, dan versi Android minimum yang dipakai?
- Ada magnetometer pembanding untuk validasi?
- Pengolahan harus offline di HP, atau cukup ekspor lalu olah di komputer?
