import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cuaca Hari Ini',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1769AA),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F6FC),
      ),
      home: const WeatherPage(),
    );
  }
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final TextEditingController _cityController =
      TextEditingController(text: 'Makassar');

  bool _loading = false;
  String? _error;
  WeatherData? _weather;

  @override
  void initState() {
    super.initState();
    _loadWeather('Makassar');
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather([String? requestedCity]) async {
    final city = (requestedCity ?? _cityController.text).trim();
    if (city.isEmpty) {
      setState(() => _error = 'Masukkan nama kota terlebih dahulu.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Cari koordinat kota menggunakan Open-Meteo Geocoding API.
      final geoUri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': city,
        'count': '1',
        'language': 'id',
        'format': 'json',
      });
      final geoResponse = await http.get(geoUri);
      if (geoResponse.statusCode != 200) {
        throw Exception('Tidak dapat mencari lokasi. Coba lagi.');
      }

      final geoJson = jsonDecode(geoResponse.body) as Map<String, dynamic>;
      final results = geoJson['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        throw Exception('Kota "$city" tidak ditemukan.');
      }

      final place = results.first as Map<String, dynamic>;
      final latitude = (place['latitude'] as num).toDouble();
      final longitude = (place['longitude'] as num).toDouble();
      final cityName = place['name'] as String? ?? city;
      final country = place['country'] as String? ?? '';

      // Ambil kondisi saat ini dan prakiraan per jam.
      final forecastUri =
          Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m',
        'hourly': 'temperature_2m,precipitation_probability',
        'forecast_days': '1',
        'timezone': 'auto',
      });
      final forecastResponse = await http.get(forecastUri);
      if (forecastResponse.statusCode != 200) {
        throw Exception('Data cuaca tidak dapat diambil. Coba lagi.');
      }

      final forecast =
          jsonDecode(forecastResponse.body) as Map<String, dynamic>;
      final current = forecast['current'] as Map<String, dynamic>;
      final hourly = forecast['hourly'] as Map<String, dynamic>;
      final times = hourly['time'] as List<dynamic>;
      final temperatures = hourly['temperature_2m'] as List<dynamic>;
      final rainChances =
          hourly['precipitation_probability'] as List<dynamic>;

      final now = DateTime.now();
      int startIndex = 0;
      int smallestDifference = 1 << 30;
      for (int i = 0; i < times.length; i++) {
        final time = DateTime.tryParse(times[i].toString());
        if (time != null) {
          final difference = time.difference(now).inMinutes.abs();
          if (difference < smallestDifference) {
            smallestDifference = difference;
            startIndex = i;
          }
        }
      }

      final hourlyItems = <HourlyWeather>[];
      for (int i = startIndex; i < times.length && hourlyItems.length < 6; i++) {
        hourlyItems.add(HourlyWeather(
          time: times[i].toString(),
          temperature: (temperatures[i] as num).toDouble(),
          rainChance: (rainChances[i] as num?)?.toInt() ?? 0,
        ));
      }

      final data = WeatherData(
        city: cityName,
        country: country,
        temperature: (current['temperature_2m'] as num).toDouble(),
        feelsLike: (current['apparent_temperature'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toInt(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        hourly: hourlyItems,
      );

      if (!mounted) return;
      setState(() {
        _weather = data;
        _cityController.text = cityName;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuaca Hari Ini',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadWeather(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _buildSearch(),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _buildError()
              else if (weather != null) ...[
                _buildCurrentWeather(weather),
                const SizedBox(height: 18),
                _buildDetails(weather),
                const SizedBox(height: 22),
                const Text(
                  'Prakiraan beberapa jam ke depan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildHourly(weather),
                const SizedBox(height: 18),
                const Text(
                  'Sumber data: Open-Meteo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _cityController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadWeather(),
            decoration: InputDecoration(
              hintText: 'Cari nama kota...',
              prefixIcon: const Icon(Icons.location_city),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _loading ? null : () => _loadWeather(),
          icon: const Icon(Icons.search),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF1769AA),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
          ),
          tooltip: 'Cari cuaca',
        ),
      ],
    );
  }

  Widget _buildCurrentWeather(WeatherData weather) {
    final info = weatherDescription(weather.weatherCode);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 19),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '${weather.city}${weather.country.isNotEmpty ? ', ${weather.country}' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Icon(info.icon, color: Colors.white, size: 76),
          const SizedBox(height: 8),
          Text(
            '${weather.temperature.round()}°C',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 62,
              height: 1.1,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            info.label,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Terasa seperti ${weather.feelsLike.round()}°C',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(WeatherData weather) {
    return Row(
      children: [
        Expanded(
          child: _detailCard(
            icon: Icons.water_drop_outlined,
            label: 'Kelembapan',
            value: '${weather.humidity}%',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _detailCard(
            icon: Icons.air,
            label: 'Kecepatan angin',
            value: '${weather.windSpeed.round()} km/j',
          ),
        ),
      ],
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1769AA), size: 28),
          const SizedBox(height: 10),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHourly(WeatherData weather) {
    if (weather.hourly.isEmpty) {
      return const Text('Data prakiraan per jam tidak tersedia.');
    }
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: weather.hourly.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = weather.hourly[index];
          final parsed = DateTime.tryParse(item.time);
          final timeLabel = parsed == null
              ? '--:--'
              : '${parsed.hour.toString().padLeft(2, '0')}:00';
          return Container(
            width: 100,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(timeLabel,
                    style: const TextStyle(
                        color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                const Icon(Icons.thermostat, color: Color(0xFF1769AA), size: 27),
                Text('${item.temperature.round()}°C',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.water_drop,
                        size: 13, color: Colors.lightBlue),
                    const SizedBox(width: 3),
                    Text('${item.rainChance}%'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 42, color: Colors.blueGrey),
          const SizedBox(height: 10),
          Text(_error ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : () => _loadWeather(),
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class WeatherData {
  final String city;
  final String country;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final List<HourlyWeather> hourly;

  const WeatherData({
    required this.city,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.hourly,
  });
}

class HourlyWeather {
  final String time;
  final double temperature;
  final int rainChance;

  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.rainChance,
  });
}

class WeatherDescription {
  final String label;
  final IconData icon;

  const WeatherDescription(this.label, this.icon);
}

WeatherDescription weatherDescription(int code) {
  if (code == 0) {
    return const WeatherDescription('Cerah', Icons.wb_sunny);
  }
  if (code == 1 || code == 2) {
    return const WeatherDescription('Cerah berawan', Icons.cloud_queue);
  }
  if (code == 3) {
    return const WeatherDescription('Berawan', Icons.cloud);
  }
  if (code == 45 || code == 48) {
    return const WeatherDescription('Berkabut', Icons.foggy);
  }
  if ([51, 53, 55, 56, 57].contains(code)) {
    return const WeatherDescription('Gerimis', Icons.grain);
  }
  if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) {
    return const WeatherDescription('Hujan', Icons.umbrella);
  }
  if ([71, 73, 75, 77, 85, 86].contains(code)) {
    return const WeatherDescription('Salju', Icons.ac_unit);
  }
  if ([95, 96, 99].contains(code)) {
    return const WeatherDescription('Badai petir', Icons.thunderstorm);
  }
  return const WeatherDescription('Kondisi tidak diketahui', Icons.cloud);
}
