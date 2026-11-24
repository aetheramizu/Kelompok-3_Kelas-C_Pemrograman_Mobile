import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/geo_point.dart';
import '../../domain/weather.dart';
import '../../services/weather_cache_service.dart';

/// Contract for fetching start-point weather with 2-layer offline fallback.
abstract interface class WeatherRepository {
  /// Fetches live weather for the current moment.
  Future<WeatherSnapshot?> fetchCurrentWeather(
    GeoPointLite startPoint, {
    Duration timeout = const Duration(seconds: 6),
  });

  /// Layer 1: Pre-caches 48-hour hourly forecast while online.
  Future<void> preCacheHourlyForecast(
    GeoPointLite startPoint, {
    Duration timeout = const Duration(seconds: 6),
  });

  /// Layer 1: Retrieves pre-cached hourly forecast matching [targetTime].
  WeatherSnapshot? getCachedForecast(
    GeoPointLite startPoint,
    DateTime targetTime,
  );

  /// Layer 2: Historical backfill for runs recorded offline.
  Future<WeatherSnapshot?> fetchHistoricalWeather(
    GeoPointLite startPoint,
    DateTime runTime, {
    Duration timeout = const Duration(seconds: 6),
  });
}

/// Open-Meteo Forecast API implementation of [WeatherRepository].
class OpenMeteoWeatherRepository implements WeatherRepository {
  OpenMeteoWeatherRepository({http.Client? client, this.cacheService})
    : _client = client ?? http.Client();

  final http.Client _client;
  final WeatherCacheService? cacheService;

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
        isCachedForecast: false,
      );
    } catch (_) {
      // Graceful degradation on network timeout, airplane mode, or parsing error.
      return null;
    }
  }

  @override
  Future<void> preCacheHourlyForecast(
    GeoPointLite startPoint, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final cache = cacheService;
    if (cache == null) return;
    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'latitude': startPoint.latitude.toString(),
          'longitude': startPoint.longitude.toString(),
          'hourly': 'temperature_2m,apparent_temperature,weather_code',
          'forecast_days': '2',
        },
      );

      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final hourly = decoded['hourly'];
      if (hourly is! Map<String, dynamic>) return;

      final times = (hourly['time'] as List<dynamic>? ?? [])
          .map((t) => DateTime.tryParse(t.toString()) ?? DateTime.now())
          .toList();
      final temps = (hourly['temperature_2m'] as List<dynamic>? ?? [])
          .map((v) => (v as num).toDouble())
          .toList();
      final apparents = (hourly['apparent_temperature'] as List<dynamic>? ?? [])
          .map((v) => (v as num).toDouble())
          .toList();
      final codes = (hourly['weather_code'] as List<dynamic>? ?? [])
          .map((v) => (v as num).toInt())
          .toList();

      if (times.isNotEmpty) {
        await cache.saveHourlyForecast(
          latitude: startPoint.latitude,
          longitude: startPoint.longitude,
          times: times,
          temperatures: temps,
          apparentTemperatures: apparents,
          weatherCodes: codes,
        );
      }
    } catch (_) {
      // Graceful degradation on network timeout.
    }
  }

  @override
  WeatherSnapshot? getCachedForecast(
    GeoPointLite startPoint,
    DateTime targetTime,
  ) {
    return cacheService?.getCachedForecastForTime(
      latitude: startPoint.latitude,
      longitude: startPoint.longitude,
      targetTime: targetTime,
    );
  }

  @override
  Future<WeatherSnapshot?> fetchHistoricalWeather(
    GeoPointLite startPoint,
    DateTime runTime, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'latitude': startPoint.latitude.toString(),
          'longitude': startPoint.longitude.toString(),
          'past_days': '7',
          'hourly': 'temperature_2m,apparent_temperature,weather_code',
        },
      );

      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final hourly = decoded['hourly'];
      if (hourly is! Map<String, dynamic>) return null;

      final times = (hourly['time'] as List<dynamic>? ?? []);
      final temps = (hourly['temperature_2m'] as List<dynamic>? ?? []);
      final apparents =
          (hourly['apparent_temperature'] as List<dynamic>? ?? []);
      final codes = (hourly['weather_code'] as List<dynamic>? ?? []);

      final targetUtc = runTime.toUtc();
      int? bestIndex;
      var minDiffMs = double.infinity;

      for (var i = 0; i < times.length; i++) {
        final t = DateTime.tryParse(times[i].toString());
        if (t == null) continue;
        final diff =
            (t.millisecondsSinceEpoch - targetUtc.millisecondsSinceEpoch).abs();
        if (diff < minDiffMs) {
          minDiffMs = diff.toDouble();
          bestIndex = i;
        }
      }

      if (bestIndex == null ||
          minDiffMs > const Duration(hours: 3).inMilliseconds) {
        return null;
      }

      final temp = temps[bestIndex];
      final apparent = apparents[bestIndex];
      final code = codes[bestIndex];
      if (temp is! num || apparent is! num || code is! num) return null;

      return WeatherSnapshot(
        temperatureC: temp.toDouble(),
        apparentC: apparent.toDouble(),
        code: code.toInt(),
        fetchedAt: runTime,
        isCachedForecast: false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// In-memory mock implementation of [WeatherRepository] for tests and preview mode.
class MockWeatherRepository implements WeatherRepository {
  MockWeatherRepository({
    this.snapshot,
    this.cachedSnapshot,
    this.historicalSnapshot,
    this.shouldFail = false,
  });

  WeatherSnapshot? snapshot;
  WeatherSnapshot? cachedSnapshot;
  WeatherSnapshot? historicalSnapshot;
  bool shouldFail;
  bool preCacheCalled = false;
  bool historicalCalled = false;

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
          isCachedForecast: false,
        );
  }

  @override
  Future<void> preCacheHourlyForecast(
    GeoPointLite startPoint, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    preCacheCalled = true;
  }

  @override
  WeatherSnapshot? getCachedForecast(
    GeoPointLite startPoint,
    DateTime targetTime,
  ) {
    if (shouldFail) return null;
    return cachedSnapshot ??
        (snapshot != null
            ? snapshot!.copyWith(isCachedForecast: true)
            : WeatherSnapshot(
                temperatureC: 26.5,
                apparentC: 28.0,
                code: 2,
                fetchedAt: targetTime,
                isCachedForecast: true,
              ));
  }

  @override
  Future<WeatherSnapshot?> fetchHistoricalWeather(
    GeoPointLite startPoint,
    DateTime runTime, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    historicalCalled = true;
    if (shouldFail) return null;
    return historicalSnapshot ??
        WeatherSnapshot(
          temperatureC: 25.0,
          apparentC: 26.5,
          code: 3,
          fetchedAt: runTime,
          isCachedForecast: false,
        );
  }
}
