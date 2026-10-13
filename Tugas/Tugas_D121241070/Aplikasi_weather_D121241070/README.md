# Cuaca Indonesia

Aplikasi Flutter satu halaman yang menampilkan cuaca dari [Open-Meteo](https://open-meteo.com) (gratis, tanpa API key).

## Struktur

```
lib/
  main.dart
  models/      class data immutable + factory fromJson
  services/    satu-satunya file yang memanggil http
  ui/
    screens/   halaman pengatur state (loading / sukses / error)
    widgets/   komponen yang menerima data lewat constructor
test/
```

## Menjalankan

```
flutter pub get
flutter analyze
flutter test
flutter run
```
