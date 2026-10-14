# Aplikasi Cuaca Sederhana (Flutter)

Aplikasi cuaca sederhana untuk tugas Pemrograman Mobile, ditulis menggunakan Dart dan Flutter.

## Fitur
- Mencari cuaca berdasarkan nama kota.
- Menampilkan suhu saat ini dan suhu yang terasa.
- Menampilkan kondisi cuaca, kelembapan, dan kecepatan angin.
- Menampilkan prakiraan suhu serta peluang hujan untuk beberapa jam ke depan.
- Tombol muat ulang dan tarik layar ke bawah untuk memperbarui data.
- Tampilan Material 3.

## API
Data diambil dari [Open-Meteo](https://open-meteo.com/). Untuk penggunaan dasar, API ini tidak memerlukan API key. Aplikasi membutuhkan koneksi internet.

## Cara menjalankan
1. Pastikan Flutter SDK dan Android Studio (atau emulator/perangkat Android) sudah terpasang.
2. Ekstrak folder proyek ini.
3. Buka terminal di folder `aplikasi_cuaca_flutter`.
4. Jalankan:

   ```bash
   flutter pub get
   flutter run
   ```

Jika ingin membuat struktur platform (android, web, dan lain-lain) di folder ini, jalankan `flutter create .` terlebih dahulu, lalu jalankan perintah di atas.

## Catatan Android
Pastikan izin internet ada di `android/app/src/main/AndroidManifest.xml`, di dalam elemen `<manifest>` dan di luar `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Template Flutter Android biasanya sudah menyediakan izin ini, tetapi periksa jika permintaan API gagal.

## Struktur
```text
aplikasi_cuaca_flutter/
├── lib/
│   └── main.dart
├── pubspec.yaml
└── README.md
```
