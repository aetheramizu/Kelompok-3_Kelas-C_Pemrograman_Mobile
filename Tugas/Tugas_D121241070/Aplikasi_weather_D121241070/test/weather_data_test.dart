import 'package:flutter_test/flutter_test.dart';
import 'package:weather/models/weather_data.dart';

void main() {
  test('WeatherData.fromJson membaca respons Open-Meteo', () {
    final times = <String>[
      for (var h = 0; h < 24; h++)
        '2026-10-13T${h.toString().padLeft(2, '0')}:00',
    ];

    final json = <String, dynamic>{
      'utc_offset_seconds': 28800,
      'current': <String, dynamic>{
        'time': '2026-10-13T14:15',
        'temperature_2m': 31.2,
        'apparent_temperature': 35.0,
        'relative_humidity_2m': 70,
        'weather_code': 3,
        'wind_speed_10m': 12.5,
        'is_day': 1,
      },
      'hourly': <String, dynamic>{
        'time': times,
        'temperature_2m': List<double>.filled(24, 30.0),
        'precipitation_probability': List<int>.filled(24, 20),
        'weather_code': List<int>.filled(24, 63),
        'is_day': List<int>.filled(24, 1),
      },
      'daily': <String, dynamic>{
        'time': <String>['2026-10-13', '2026-10-14'],
        'weather_code': <int>[3, 61],
        'temperature_2m_max': <double>[33.0, 32.0],
        'temperature_2m_min': <double>[25.0, 24.0],
        'precipitation_probability_max': <int>[40, 80],
      },
    };

    final data = WeatherData.fromJson(json);

    expect(data.timezoneLabel, 'WITA');
    expect(data.current.temperature, 31.2);
    expect(data.hourly.length, 10);
    expect(data.hourly.first.time.hour, 14);
    expect(data.daily.length, 2);
    expect(data.daily.last.precipitationProbability, 80);
  });
}
