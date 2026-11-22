import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nearpace/data/repositories/weather_repository.dart';
import 'package:nearpace/domain/geo_point.dart';

void main() {
  group('OpenMeteoWeatherRepository', () {
    const point = GeoPointLite(latitude: -5.147665, longitude: 119.432732);

    test('successfully parses valid 200 OK Open-Meteo response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.path, '/v1/forecast');
        expect(
          request.url.queryParameters['latitude'],
          point.latitude.toString(),
        );
        expect(
          request.url.queryParameters['longitude'],
          point.longitude.toString(),
        );

        final payload = {
          'latitude': -5.15,
          'longitude': 119.43,
          'current': {
            'time': '2026-11-22T07:00',
            'interval': 900,
            'temperature_2m': 28.4,
            'apparent_temperature': 31.2,
            'weather_code': 2,
          },
        };
        return http.Response(jsonEncode(payload), 200);
      });

      final repo = OpenMeteoWeatherRepository(client: mockClient);
      final weather = await repo.fetchCurrentWeather(point);

      expect(weather, isNotNull);
      expect(weather!.temperatureC, 28.4);
      expect(weather.apparentC, 31.2);
      expect(weather.code, 2);
      expect(weather.label, 'Partly cloudy');
    });

    test('degrades gracefully to null on HTTP 500 status code', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final repo = OpenMeteoWeatherRepository(client: mockClient);
      final weather = await repo.fetchCurrentWeather(point);

      expect(weather, isNull);
    });

    test('degrades gracefully to null on malformed JSON payload', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{ invalid json structure }', 200);
      });

      final repo = OpenMeteoWeatherRepository(client: mockClient);
      final weather = await repo.fetchCurrentWeather(point);

      expect(weather, isNull);
    });

    test('degrades gracefully to null on missing current fields', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'latitude': 10.0}), 200);
      });

      final repo = OpenMeteoWeatherRepository(client: mockClient);
      final weather = await repo.fetchCurrentWeather(point);

      expect(weather, isNull);
    });

    test('degrades gracefully to null on request timeout', () async {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          '{"current":{"temperature_2m":25,"apparent_temperature":25,"weather_code":0}}',
          200,
        );
      });

      final repo = OpenMeteoWeatherRepository(client: mockClient);
      final weather = await repo.fetchCurrentWeather(
        point,
        timeout: const Duration(milliseconds: 10),
      );

      expect(weather, isNull);
    });
  });
}
