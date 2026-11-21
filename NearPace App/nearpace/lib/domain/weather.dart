/// WMO weather interpretation codes used by Open-Meteo.
String weatherCodeLabel(int? code) {
  if (code == null) return 'Unknown';
  if (code == 0) return 'Clear sky';
  if (code <= 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Fog';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code >= 85 && code <= 86) return 'Snow showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Unknown';
}

/// Conditions at the start of a run, fetched once and cached in the activity.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.apparentC,
    required this.code,
    required this.fetchedAt,
  });

  final double temperatureC;
  final double apparentC;
  final int code;
  final DateTime fetchedAt;

  String get label => weatherCodeLabel(code);

  Map<String, dynamic> toMap() => {
    'temperatureC': temperatureC,
    'apparentC': apparentC,
    'code': code,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  };

  static WeatherSnapshot? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final fetched = DateTime.tryParse(map['fetchedAt'] as String? ?? '');
    if (fetched == null) return null;
    return WeatherSnapshot(
      temperatureC: (map['temperatureC'] as num).toDouble(),
      apparentC: (map['apparentC'] as num).toDouble(),
      code: (map['code'] as num).toInt(),
      fetchedAt: fetched,
    );
  }
}
