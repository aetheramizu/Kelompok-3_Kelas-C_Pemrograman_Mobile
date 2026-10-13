import 'package:flutter/material.dart';
import 'package:weather/models/city.dart';
import 'package:weather/models/weather_data.dart';
import 'package:weather/services/weather_service.dart';
import 'package:weather/ui/widgets/current_weather_card.dart';
import 'package:weather/ui/widgets/daily_list.dart';
import 'package:weather/ui/widgets/error_view.dart';
import 'package:weather/ui/widgets/hourly_list.dart';
import 'package:weather/ui/widgets/loading_view.dart';

/// Satu-satunya halaman aplikasi. Layar ini memegang state
/// (loading / sukses / error) dan mengirim data ke widget lewat constructor.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _service = WeatherService();

  City _city = indonesianCities.first;
  WeatherData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    final requestedCity = _city;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _service.fetchWeather(requestedCity);
      if (!mounted || requestedCity != _city) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } on WeatherException catch (e) {
      if (!mounted || requestedCity != _city) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _selectCity(City city) {
    if (city == _city) return;
    setState(() => _city = city);
    _load();
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();

    final error = _error;
    if (error != null) {
      return ErrorView(message: error, onRetry: () => _load());
    }

    final data = _data;
    if (data == null) return const LoadingView();

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CurrentWeatherCard(
            city: _city,
            current: data.current,
            timezoneLabel: data.timezoneLabel,
          ),
          const SizedBox(height: 16),
          HourlyList(hours: data.hourly),
          const SizedBox(height: 16),
          DailyList(days: data.daily),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuaca Indonesia'),
        actions: [
          PopupMenuButton<City>(
            tooltip: 'Pilih kota',
            icon: const Icon(Icons.location_city),
            onSelected: _selectCity,
            itemBuilder: (context) => [
              for (final city in indonesianCities)
                PopupMenuItem<City>(
                  value: city,
                  child: Text('${city.name}, ${city.province}'),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }
}
