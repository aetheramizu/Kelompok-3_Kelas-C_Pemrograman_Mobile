import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/geo_point.dart';
import '../../domain/weather.dart';

/// Contract for fetching start-point weather.
abstract interface class WeatherRepository {
  Future<WeatherSnapshot?> fetchCurrentWeather(
    GeoPointLite startPoint, {
    Duration timeout = const Duration(seconds: 6),
  });
}

/// Open-Meteo Forecast API implementation of [WeatherRepository].
class OpenMeteoWeatherRepository implements WeatherRepository {
  OpenMeteoWeatherRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  @override
  Future<WeatherSnapshot?> fetchCurrentWeather(
    GeoPointLite startPoint, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'latitude': startPoint.latitude.toString(),
          'longitude': startPoint.longitude.toString(),
          'current': 'temperature_2m,apparent_temperature,weather_code',
        },
      );

      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final current = decoded['current'];
      if (current is! Map<String, dynamic>) {
        return null;
      }

      final temp = current['temperature_2m'];
      final apparent = current['apparent_temperature'];
      final code = current['weather_code'];

      if (temp is! num || apparent is! num || code is! num) {
        return null;
      }

      return WeatherSnapshot(
        temperatureC: temp.toDouble(),
        apparentC: apparent.toDouble(),
        code: code.toInt(),
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      // Graceful degradation on network timeout, airplane mode, or parsing error.
      return null;
    }
  }
}

/// In-memory mock implementation of [WeatherRepository] for tests and preview mode.
class MockWeatherRepository implements WeatherRepository {
  MockWeatherRepository({this.snapshot, this.shouldFail = false});

  WeatherSnapshot? snapshot;
  bool shouldFail;

  @override
  Future<WeatherSnapshot?> fetchCurrentWeather(
    GeoPointLite startPoint, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (shouldFail) return null;
    return snapshot ??
        WeatherSnapshot(
          temperatureC: 27.6,
          apparentC: 29.9,
          code: 1,
          fetchedAt: DateTime.now(),
        );
  }
}
