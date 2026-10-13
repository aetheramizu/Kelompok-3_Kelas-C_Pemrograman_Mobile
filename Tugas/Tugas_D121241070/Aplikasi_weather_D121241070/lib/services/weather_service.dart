import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:weather/models/city.dart';
import 'package:weather/models/weather_data.dart';

/// Error dengan pesan yang siap ditampilkan ke pengguna.
class WeatherException implements Exception {
  const WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Satu-satunya tempat di aplikasi yang memanggil http.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WeatherData> fetchWeather(City city) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': city.latitude.toString(),
      'longitude': city.longitude.toString(),
      'timezone': 'auto',
      'forecast_days': '14',
      'wind_speed_unit': 'kmh',
      'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,'
          'weather_code,wind_speed_10m,is_day',
      'hourly': 'temperature_2m,precipitation_probability,weather_code,is_day',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
          'precipitation_probability_max',
    });

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const WeatherException(
          'Permintaan terlalu lama. Periksa koneksi internet Anda lalu coba lagi.');
    } on http.ClientException {
      throw const WeatherException(
          'Tidak ada koneksi internet. Sambungkan ke jaringan lalu coba lagi.');
    }

    if (response.statusCode != 200) {
      throw WeatherException(
          'Server cuaca bermasalah (kode ${response.statusCode}). Coba lagi nanti.');
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return WeatherData.fromJson(decoded);
    } catch (_) {
      throw const WeatherException(
          'Data dari server tidak bisa dibaca. Coba lagi nanti.');
    }
  }

  void dispose() => _client.close();
}
