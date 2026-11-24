import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/weather.dart';

/// Contract for pre-caching 48-hour hourly weather forecasts for offline use.
abstract interface class WeatherCacheService {
  Future<void> saveHourlyForecast({
    required double latitude,
    required double longitude,
    required List<DateTime> times,
    required List<double> temperatures,
    required List<double> apparentTemperatures,
    required List<int> weatherCodes,
  });

  WeatherSnapshot? getCachedForecastForTime({
    required double latitude,
    required double longitude,
    required DateTime targetTime,
  });

  Future<void> clearCache();
}

/// SharedPreferences-backed implementation of [WeatherCacheService].
class PreferencesWeatherCacheService implements WeatherCacheService {
  PreferencesWeatherCacheService({SharedPreferences? preferences})
    : _prefs = preferences;

  SharedPreferences? _prefs;
  static const String _storageKey = 'nearpace_weather_forecast_cache';

  // In-memory cache for synchronous lookup
  Map<String, dynamic>? _memoryCache;

  Future<SharedPreferences> _getPrefs() async {
    final existing = _prefs;
    if (existing != null) return existing;
    final loaded = await SharedPreferences.getInstance();
    _prefs = loaded;
    return loaded;
  }

  Future<void> init() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        _memoryCache = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        _memoryCache = null;
      }
    }
  }

  @override
  Future<void> saveHourlyForecast({
    required double latitude,
    required double longitude,
    required List<DateTime> times,
    required List<double> temperatures,
    required List<double> apparentTemperatures,
    required List<int> weatherCodes,
  }) async {
    final count = [
      times.length,
      temperatures.length,
      apparentTemperatures.length,
      weatherCodes.length,
    ].reduce(math.min);

    final entries = <Map<String, dynamic>>[];
    for (var i = 0; i < count; i++) {
      entries.add({
        'time': times[i].toUtc().toIso8601String(),
        'temp': temperatures[i],
        'apparent': apparentTemperatures[i],
        'code': weatherCodes[i],
      });
    }

    final data = {
      'latitude': latitude,
      'longitude': longitude,
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
      'entries': entries,
    };

    _memoryCache = data;
    final prefs = await _getPrefs();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  @override
  WeatherSnapshot? getCachedForecastForTime({
    required double latitude,
    required double longitude,
    required DateTime targetTime,
  }) {
    final cache = _memoryCache;
    if (cache == null) return null;

    final cachedLat = (cache['latitude'] as num?)?.toDouble();
    final cachedLng = (cache['longitude'] as num?)?.toDouble();
    if (cachedLat == null || cachedLng == null) return null;

    // Reject if location is too far (> 0.5 deg ≈ 55 km)
    final dLat = (cachedLat - latitude).abs();
    final dLng = (cachedLng - longitude).abs();
    if (dLat > 0.5 || dLng > 0.5) return null;

    final rawEntries = cache['entries'] as List<dynamic>?;
    if (rawEntries == null || rawEntries.isEmpty) return null;

    final targetUtc = targetTime.toUtc();
    Map<String, dynamic>? closestEntry;
    var minDiffMs = double.infinity;

    for (final raw in rawEntries) {
      if (raw is! Map<String, dynamic>) continue;
      final timeStr = raw['time'] as String?;
      if (timeStr == null) continue;
      final entryTime = DateTime.tryParse(timeStr);
      if (entryTime == null) continue;

      final diff =
          (entryTime.millisecondsSinceEpoch - targetUtc.millisecondsSinceEpoch)
              .abs();
      if (diff < minDiffMs) {
        minDiffMs = diff.toDouble();
        closestEntry = raw;
      }
    }

    // Must be within 3 hours of the run start
    if (closestEntry == null ||
        minDiffMs > const Duration(hours: 3).inMilliseconds) {
      return null;
    }

    final temp = (closestEntry['temp'] as num?)?.toDouble();
    final apparent = (closestEntry['apparent'] as num?)?.toDouble();
    final code = (closestEntry['code'] as num?)?.toInt();
    if (temp == null || apparent == null || code == null) return null;

    return WeatherSnapshot(
      temperatureC: temp,
      apparentC: apparent,
      code: code,
      fetchedAt: targetTime,
      isCachedForecast: true,
    );
  }

  @override
  Future<void> clearCache() async {
    _memoryCache = null;
    final prefs = await _getPrefs();
    await prefs.remove(_storageKey);
  }
}

/// In-memory implementation of [WeatherCacheService] for unit tests.
class InMemoryWeatherCacheService implements WeatherCacheService {
  Map<String, dynamic>? _cache;

  @override
  Future<void> saveHourlyForecast({
    required double latitude,
    required double longitude,
    required List<DateTime> times,
    required List<double> temperatures,
    required List<double> apparentTemperatures,
    required List<int> weatherCodes,
  }) async {
    final count = [
      times.length,
      temperatures.length,
      apparentTemperatures.length,
      weatherCodes.length,
    ].reduce(math.min);

    final entries = <Map<String, dynamic>>[];
    for (var i = 0; i < count; i++) {
      entries.add({
        'time': times[i].toUtc().toIso8601String(),
        'temp': temperatures[i],
        'apparent': apparentTemperatures[i],
        'code': weatherCodes[i],
      });
    }

    _cache = {
      'latitude': latitude,
      'longitude': longitude,
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
      'entries': entries,
    };
  }

  @override
  WeatherSnapshot? getCachedForecastForTime({
    required double latitude,
    required double longitude,
    required DateTime targetTime,
  }) {
    final cache = _cache;
    if (cache == null) return null;

    final cachedLat = (cache['latitude'] as num?)?.toDouble();
    final cachedLng = (cache['longitude'] as num?)?.toDouble();
    if (cachedLat == null || cachedLng == null) return null;

    final dLat = (cachedLat - latitude).abs();
    final dLng = (cachedLng - longitude).abs();
    if (dLat > 0.5 || dLng > 0.5) return null;

    final rawEntries = cache['entries'] as List<dynamic>?;
    if (rawEntries == null || rawEntries.isEmpty) return null;

    final targetUtc = targetTime.toUtc();
    Map<String, dynamic>? closestEntry;
    var minDiffMs = double.infinity;

    for (final raw in rawEntries) {
      if (raw is! Map<String, dynamic>) continue;
      final timeStr = raw['time'] as String?;
      if (timeStr == null) continue;
      final entryTime = DateTime.tryParse(timeStr);
      if (entryTime == null) continue;

      final diff =
          (entryTime.millisecondsSinceEpoch - targetUtc.millisecondsSinceEpoch)
              .abs();
      if (diff < minDiffMs) {
        minDiffMs = diff.toDouble();
        closestEntry = raw;
      }
    }

    if (closestEntry == null ||
        minDiffMs > const Duration(hours: 3).inMilliseconds) {
      return null;
    }

    final temp = (closestEntry['temp'] as num?)?.toDouble();
    final apparent = (closestEntry['apparent'] as num?)?.toDouble();
    final code = (closestEntry['code'] as num?)?.toInt();
    if (temp == null || apparent == null || code == null) return null;

    return WeatherSnapshot(
      temperatureC: temp,
      apparentC: apparent,
      code: code,
      fetchedAt: targetTime,
      isCachedForecast: true,
    );
  }

  @override
  Future<void> clearCache() async {
    _cache = null;
  }
}
