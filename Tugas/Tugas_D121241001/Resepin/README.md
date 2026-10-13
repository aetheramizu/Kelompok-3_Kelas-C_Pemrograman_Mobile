# Resepin

Aplikasi penemuan resep berbasis Flutter yang mengambil data dari [TheMealDB](https://www.themealdb.com/) REST API. Dibuat untuk tugas mata kuliah Pemrograman Mobile.

## Fitur

- **Beranda** — rekomendasi resep acak ("Saran hari ini") dengan tombol refresh, filter kategori berbasis chip yang dapat digulir horizontal, dan grid resep dua kolom.
- **Pencarian** — pencarian resep berdasarkan nama (submit-driven: request hanya berjalan saat tombol cari ditekan), lengkap dengan state awal, hasil kosong, error, dan retry.
- **Detail resep** — gambar, kategori/asal masakan, daftar bahan dengan takaran, dan instruksi; diakses dari Beranda maupun hasil pencarian.
- **Penanganan state lengkap** — skeleton loading, error dengan tombol "Coba lagi", empty state, dan fallback gambar saat gagal dimuat.

## Teknologi

- Flutter / Dart (SDK `^3.13.1`)
- [`http`](https://pub.dev/packages/http) untuk HTTP request — tanpa state management eksternal (murni `StatefulWidget` + `setState`, tanpa Provider/Bloc).
- TheMealDB API v1 (publik, tanpa API key).

## Struktur Proyek

```
lib/
├── main.dart            # Entry point aplikasi
├── models/              # Model data immutable (Meal, MealCategory) dengan factory fromJson
├── services/            # meal_api.dart — klien HTTP terpusat untuk seluruh endpoint
├── theme/               # Token desain & tema (warna, spacing, radius, tipografi)
└── ui/
    ├── screens/         # Layar aplikasi (StatefulWidget pengelola state)
    └── widgets/         # Komponen reusable (menerima data via constructor)
```

## Endpoint API

Base URL: `https://www.themealdb.com/api/json/v1/1/`

| Endpoint | Fungsi |
|---|---|
| `categories.php` | Daftar kategori |
| `filter.php?c={kategori}` | Resep dalam satu kategori |
| `random.php` | Satu resep acak |
| `search.php?s={query}` | Pencarian resep berdasarkan nama |
| `lookup.php?i={id}` | Detail resep berdasarkan ID |

## Menjalankan

```bash
flutter pub get
flutter run
```

Izin internet Android sudah dikonfigurasi di `android/app/src/main/AndroidManifest.xml`.

## Pengujian

```bash
flutter analyze   # tanpa error
flutter test      # seluruh test lulus
```

Test mencakup parsing model, API service (memakai `MockClient` — tanpa jaringan langsung), widget Beranda/Cari/Detail, layout grid, chip kategori, dan skala teks besar (1.3x–2.0x).

## Catatan Desain

- Palet krem + hijau editorial dengan aksen terakota terbatas; tanpa gradient, glassmorphism, atau shadow berlebihan.
- Font judul: [Fraunces](https://fonts.google.com/specimen/Fraunces) — lisensi SIL Open Font License 1.1, berkas lisensi di `assets/fonts/fraunces/OFL.txt`. Teks isi memakai font sistem.
- Semua data berasal dari API — tidak ada rating, waktu masak, atau porsi yang dikarang.
