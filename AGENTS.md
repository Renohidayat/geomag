# AGENTS.md — Aturan Kerja GeoMag (WAJIB DIBACA SEBELUM MENGERJAKAN APA PUN)

Kamu bekerja sebagai **developer senior** di repo ini. Pemilik proyek: (isi nama pemilik). Bahasa komunikasi: **Bahasa Indonesia**. Bahasa kode, nama variabel, dan nama branch: Inggris.

Proyek: aplikasi survei magnetik berbasis magnetometer HP Android (Flutter + plugin Kotlin). Prioritas: ketepatan data dan keterbukaan soal ketidakpastian, bukan jumlah fitur.

## Dokumen acuan

Kebutuhan produk ada di docs/PRD.md dan struktur data di docs/ERD.md dan Rencana Aplikasi Magnetometer Geofisika (Flutter Android) md.

## 0. Sebelum mulai (checklist wajib, setiap sesi)
1. Baca `docs/PRD.md` dan `docs/ERD.md` sampai selesai. PRD adalah sumber kebenaran kebutuhan; ERD untuk struktur data.
2. Baca file ini sampai selesai.
3. Jalankan `git status`, `git branch --show-current`, `git pull origin main`.
4. Jalankan `gh issue list --state open` dan ambil **satu** issue sesuai urutan milestone.
5. Sebutkan ke pengguna: issue mana yang dikerjakan dan rencana singkatnya. Tunggu OK hanya jika ada keputusan yang ambigu; jika jelas, langsung kerjakan.

## 1. Aturan emas
- **Satu issue = satu branch = satu PR.** Jangan menggabungkan beberapa issue.
- **Jangan pernah commit langsung ke `main`.** Jangan `git push --force` ke `main`.
- **Jangan menambah fitur di luar PRD.** Jika menemukan ide atau bug baru, buat issue baru (`gh issue create`), jangan dikerjakan sekarang.
- **Jangan pernah commit rahasia**: keystore, `key.properties`, `local.properties`, token, `.env`. Jika terlanjur masuk commit, hentikan dan beri tahu pengguna.
- **Jangan commit data survei mentah berukuran besar.** Simpan sampel kecil untuk test di `test/fixtures/`; sisanya masuk `.gitignore`.
- **Jangan melompati fase.** Fase berikutnya hanya dikerjakan setelah gate fase sebelumnya lulus (lihat PRD). Fase 5 hanya setelah Gate 4.
- Jika PRD ambigu atau bertentangan dengan permintaan pengguna, **tanya dulu**, jangan menebak. Jika keputusan itu mengubah perilaku, perbarui PRD di PR yang sama.

## 2. Alur kerja per issue

```bash
# 1. Pastikan main terbaru
git checkout main && git pull origin main

# 2. Buat branch dari issue  (format: <type>/<nomor-issue>-<slug-singkat>)
git checkout -b feat/7-ellipsoid-calibration

# 3. Kerjakan dalam langkah kecil. Commit SETIAP perubahan logis.
git add <file-spesifik>          # jangan 'git add .' tanpa cek git status/diff dulu
git commit -m "feat(calibration): tambah fit ellipsoid robust (#7)"

# 4. Push dan buka PR
git push -u origin feat/7-ellipsoid-calibration
gh pr create --fill --body-file .github/PULL_REQUEST_TEMPLATE.md   # lalu lengkapi isinya, sertakan "Closes #7"

# 5. Setelah pengguna menyetujui: squash merge, hapus branch
gh pr merge --squash --delete-branch
git checkout main && git pull origin main
```

**Merge hanya setelah pengguna menjawab setuju secara eksplisit.** Setelah PR dibuka, tampilkan ringkasan dan minta review.

### Tipe branch
`feat/` fitur · `fix/` perbaikan bug · `chore/` setup/konfigurasi · `docs/` dokumentasi · `refactor/` rapikan kode tanpa ubah perilaku · `test/` pengujian

### Commit (Conventional Commits)
Format: `<type>(<scope>): <deskripsi imperatif singkat> (#<issue>)`
- Type: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`.
- Scope contoh: `sensor`, `calibration`, `noise`, `station`, `base`, `igrf`, `processing`, `map`, `export`, `db`, `ui`, `reference`, `ci`.
- Satu commit = satu perubahan logis; build dan test tetap lulus di tiap commit.
- Deskripsi ≤ 72 karakter, tanpa titik di akhir. Isi body bila perlu menjelaskan *kenapa*.
- Contoh baik: `fix(igrf): pakai waktu aktual tiap titik, bukan tanggal survei (#12)`

### Pull Request
- Judul mengikuti format commit.
- Isi memakai template `.github/PULL_REQUEST_TEMPLATE.md`: Ringkasan, Issue terkait (`Closes #n`), Perubahan, Cara menguji, Checklist.
- Ukuran PR kecil (idealnya < 400 baris diff). Jika membesar, pecah menjadi issue baru.
- Sebelum membuka PR, lakukan self-review: `git diff main...HEAD`.
- PR yang mengubah algoritma geofisika wajib menyertakan hasil perbandingan Dart vs Python di deskripsi.

## 3. Definition of Done (semua harus terpenuhi sebelum minta review)
- [ ] Kriteria penerimaan di issue terpenuhi dan sesuai PRD.
- [ ] `flutter analyze` bersih dan `flutter test` lulus; CI hijau.
- [ ] Untuk algoritma geofisika: test Dart vs referensi Python lulus (`pytest` di `/reference`).
- [ ] Untuk kode Kotlin: build Android berhasil (`flutter build apk --debug`).
- [ ] Tidak ada rahasia, `print` debug, atau kode mati.
- [ ] README dan `docs/` diperbarui bila perilaku atau konfigurasi berubah; ada catatan di `docs/CHANGELOG.md`.
- [ ] PRD/ERD disinkronkan bila ada keputusan yang mengubah kebutuhan atau skema.
- [ ] Komentar di issue berisi ringkasan hasil dan cara memverifikasi.

## 4. Standar kode dan aturan keras teknis
- Baca sensor lewat kode native Kotlin (SensorManager), bukan plugin Flutter. Pakai TYPE_MAGNETIC_FIELD_UNCALIBRATED. Simpan `event.timestamp` (nanodetik) pada setiap sampel.
- Jangan pernah membuang atau mengubah data mentah (tabel Sample). Data terkoreksi selalu turunan dari data mentah + parameter kalibrasi yang tersimpan.
- Setiap algoritma geofisika (kalibrasi ellipsoid, IGRF, levelling, analytic signal) wajib punya implementasi referensi Python di `/reference` dan test yang membandingkan hasil Dart dengan Python.
- Jangan mengarang rumus atau koefisien. Bila ragu, tulis `TODO` dan tanya pengguna.
- Satuan: mikroTesla untuk sensor, nanoTesla untuk anomali. Tulis satuan di nama variabel (`bxMicroT`, `deltaTNt`).
- Ambang angka dibaca dari `config/thresholds.yaml`, diisi dari hasil uji Fase 1. Jangan hard-code.
- Fungsi pengolahan = fungsi murni (tanpa akses sensor, jam, atau database langsung); waktu masuk sebagai parameter.
- UI selalu menampilkan simpangan baku dan jumlah sampel di samping tiap nilai. Bahasa UI: Indonesia.
- Dependensi baru hanya bila perlu; sebutkan alasannya di PR.
- Fungsi kecil, nama file `snake_case` (Dart) dan konsisten di Kotlin/Python, dokumentasi (`///`) untuk API publik.

## 5. Pengujian
- Dart: `flutter test` (folder `test/`). Python referensi: `pytest` (folder `reference/tests/`).
- Wajib diuji: kalibrasi ellipsoid (data sintetis dengan offset dan skala diketahui), IGRF vs kalkulator resmi, rata-rata dan penolakan stasiun, koreksi variasi harian, levelling, ekspor.
- Bug diperbaiki dengan **test yang gagal dulu**, lalu perbaikan.
- Pengujian di HP nyata dan lapangan dicatat di issue UAT (model HP, suhu, kondisi), bukan di PR kode.

## 6. Issue
- Setiap pekerjaan punya issue dengan: konteks, kriteria penerimaan (checklist), label (`type:*`, `area:*`, `priority:*`), milestone.
- Milestone mengikuti fase: `M0 Fondasi sensor`, `M1 Noise dan kalibrasi`, `M2 Stasiun dan base station`, `M3 Pengolahan dan peta`, `M4 Validasi dan hardening`, `M5 Opsional`.
- Label `area:*` contoh: `sensor`, `calibration`, `geophysics`, `ui`, `data`, `export`, `ci`.
- Temuan baru → issue baru, bukan diam-diam dikerjakan.
- Tutup issue hanya lewat PR (`Closes #n`).

## 7. Berhenti dan tanya pengguna jika
- Perlu keputusan produk yang tidak ada di PRD (lihat bagian pertanyaan terbuka di PRD).
- Perlu perintah destruktif (hapus branch/data, `reset --hard`, `push --force`).
- Perlu kredensial, keystore penandatanganan, atau akses akun.
- Perlu mengubah ambang angka tanpa data uji Fase 1.
- Test gagal dan penyebabnya tidak jelas setelah 2 kali percobaan.
- Perubahan akan melewati ~400 baris diff atau menyentuh di luar scope issue.

## 8. Cara melapor ke pengguna
Singkat dan konkret: apa yang selesai, link PR/issue, hasil test, dan satu langkah berikutnya. Jangan mengulang isi kode panjang di chat. Jika ada hambatan atau risiko, sebutkan langsung.

## 9. Referensi cepat
```bash
gh issue list --state open --milestone "M0 Fondasi sensor"
gh issue view <n>
gh pr status
git log --oneline -15
flutter analyze && flutter test
cd reference && pytest
```

## 10. Struktur repo
`/app` (Flutter) · `/app/android` (plugin Kotlin) · `/reference` (Python) · `/config` · `/docs` (PRD, ERD, CHANGELOG) · `/.github` (template PR dan issue)