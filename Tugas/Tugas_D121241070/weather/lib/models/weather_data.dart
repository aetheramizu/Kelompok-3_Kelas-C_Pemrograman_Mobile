/// Cuaca saat ini.
class CurrentWeather {
  const CurrentWeather({
    required this.time,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
  });

  final DateTime time;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final bool isDay;

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      time: DateTime.parse(json['time'] as String),
      temperature: (json['temperature_2m'] as num).toDouble(),
      feelsLike: (json['apparent_temperature'] as num).toDouble(),
      humidity: (json['relative_humidity_2m'] as num).toInt(),
      windSpeed: (json['wind_speed_10m'] as num).toDouble(),
      weatherCode: (json['weather_code'] as num).toInt(),
      isDay: (json['is_day'] as num) == 1,
    );
  }
}

/// Prakiraan untuk satu jam.
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.precipitationProbability,
    required this.weatherCode,
    required this.isDay,
  });

  final DateTime time;
  final double temperature;
  final int precipitationProbability;
  final int weatherCode;
  final bool isDay;

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      time: DateTime.parse(json['time'] as String),
      temperature: (json['temperature_2m'] as num).toDouble(),
      precipitationProbability:
          (json['precipitation_probability'] as num?)?.toInt() ?? 0,
      weatherCode: (json['weather_code'] as num).toInt(),
      isDay: (json['is_day'] as num) == 1,
    );
  }
}

/// Prakiraan untuk satu hari.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.temperatureMax,
    required this.temperatureMin,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  final DateTime date;
  final double temperatureMax;
  final double temperatureMin;
  final int precipitationProbability;
  final int weatherCode;

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: DateTime.parse(json['time'] as String),
      temperatureMax: (json['temperature_2m_max'] as num).toDouble(),
      temperatureMin: (json['temperature_2m_min'] as num).toDouble(),
      precipitationProbability:
          (json['precipitation_probability_max'] as num?)?.toInt() ?? 0,
      weatherCode: (json['weather_code'] as num).toInt(),
    );
  }
}

/// Seluruh respons prakiraan cuaca dari Open-Meteo.
class WeatherData {
  const WeatherData({
    required this.utcOffsetSeconds,
    required this.current,
    required this.hourly,
    required this.daily,
  });

  final int utcOffsetSeconds;
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;

  /// WIB / WITA / WIT sesuai zona waktu lokasi.
  String get timezoneLabel {
    final hours = utcOffsetSeconds ~/ 3600;
    switch (hours) {
      case 7:
        return 'WIB';
      case 8:
        return 'WITA';
      case 9:
        return 'WIT';
      default:
        return 'UTC${hours >= 0 ? '+' : ''}$hours';
    }
  }

  /// Open-Meteo mengirim data per kolom (array terpisah per field).
  /// Di sini kolom diubah menjadi daftar objek, mulai dari jam saat ini.
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current =
        CurrentWeather.fromJson(json['current'] as Map<String, dynamic>);
    final hourly = json['hourly'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    final hourTimes = hourly['time'] as List<dynamic>;
    final currentHour =
        '${current.time.toIso8601String().substring(0, 13)}:00';
    var start = hourTimes
        .indexWhere((t) => (t as String).compareTo(currentHour) >= 0);
    if (start < 0) start = 0;

    Object? hourAt(String key, int i) => (hourly[key] as List<dynamic>)[i];

    final hours = <HourlyForecast>[];
    for (var i = start; i < hourTimes.length && hours.length < 24; i++) {
      hours.add(HourlyForecast.fromJson({
        'time': hourTimes[i],
        'temperature_2m': hourAt('temperature_2m', i),
        'precipitation_probability': hourAt('precipitation_probability', i),
        'weather_code': hourAt('weather_code', i),
        'is_day': hourAt('is_day', i),
      }));
    }

    final dayTimes = daily['time'] as List<dynamic>;
    Object? dayAt(String key, int i) => (daily[key] as List<dynamic>)[i];

    final days = <DailyForecast>[
      for (var i = 0; i < dayTimes.length; i++)
        DailyForecast.fromJson({
          'time': dayTimes[i],
          'temperature_2m_max': dayAt('temperature_2m_max', i),
          'temperature_2m_min': dayAt('temperature_2m_min', i),
          'precipitation_probability_max':
              dayAt('precipitation_probability_max', i),
          'weather_code': dayAt('weather_code', i),
        }),
    ];

    return WeatherData(
      utcOffsetSeconds: (json['utc_offset_seconds'] as num?)?.toInt() ?? 0,
      current: current,
      hourly: List<HourlyForecast>.unmodifiable(hours),
      daily: List<DailyForecast>.unmodifiable(days),
    );
  }
}
