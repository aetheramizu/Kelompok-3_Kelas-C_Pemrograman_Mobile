/// Kota yang bisa dipilih pengguna. Hanya berisi nama dan koordinat;
/// seluruh data cuaca tetap diambil dari API.
class City {
  const City({
    required this.name,
    required this.province,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String province;
  final double latitude;
  final double longitude;
}

const List<City> indonesianCities = [
  City(name: 'Makassar', province: 'Sulawesi Selatan', latitude: -5.1477, longitude: 119.4327),
  City(name: 'Jakarta', province: 'DKI Jakarta', latitude: -6.2088, longitude: 106.8456),
  City(name: 'Bandung', province: 'Jawa Barat', latitude: -6.9175, longitude: 107.6191),
  City(name: 'Surabaya', province: 'Jawa Timur', latitude: -7.2575, longitude: 112.7521),
  City(name: 'Yogyakarta', province: 'DI Yogyakarta', latitude: -7.7956, longitude: 110.3695),
  City(name: 'Medan', province: 'Sumatera Utara', latitude: 3.5952, longitude: 98.6722),
  City(name: 'Palembang', province: 'Sumatera Selatan', latitude: -2.9761, longitude: 104.7754),
  City(name: 'Pontianak', province: 'Kalimantan Barat', latitude: -0.0263, longitude: 109.3425),
  City(name: 'Balikpapan', province: 'Kalimantan Timur', latitude: -1.2379, longitude: 116.8529),
  City(name: 'Denpasar', province: 'Bali', latitude: -8.6705, longitude: 115.2126),
  City(name: 'Manado', province: 'Sulawesi Utara', latitude: 1.4748, longitude: 124.8421),
  City(name: 'Jayapura', province: 'Papua', latitude: -2.5337, longitude: 140.7181),
];
