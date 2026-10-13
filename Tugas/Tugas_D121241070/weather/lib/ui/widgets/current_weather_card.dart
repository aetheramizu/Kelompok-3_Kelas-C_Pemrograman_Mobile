import 'package:flutter/material.dart';
import 'package:weather/models/city.dart';
import 'package:weather/models/weather_code.dart';
import 'package:weather/models/weather_data.dart';
import 'package:weather/ui/widgets/formatters.dart';
import 'package:weather/ui/widgets/weather_icon.dart';

class CurrentWeatherCard extends StatelessWidget {
  const CurrentWeatherCard({
    super.key,
    required this.city,
    required this.current,
    required this.timezoneLabel,
  });

  final City city;
  final CurrentWeather current;
  final String timezoneLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final onColor = scheme.onPrimaryContainer;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              city.name,
              style: textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: onColor),
            ),
            Text(
              '${city.province} \u2022 ${formatClock(current.time)} $timezoneLabel',
              style: textTheme.bodyMedium?.copyWith(color: onColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  weatherIcon(current.weatherCode, isDay: current.isDay),
                  size: 72,
                  color: onColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${current.temperature.round()}\u00B0C',
                        style: textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold, color: onColor),
                      ),
                      Text(
                        describeWeatherCode(current.weatherCode),
                        style: textTheme.titleMedium?.copyWith(color: onColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoItem(
                  icon: Icons.thermostat,
                  label: 'Terasa',
                  value: '${current.feelsLike.round()}\u00B0',
                ),
                _InfoItem(
                  icon: Icons.water_drop,
                  label: 'Kelembapan',
                  value: '${current.humidity}%',
                ),
                _InfoItem(
                  icon: Icons.air,
                  label: 'Angin',
                  value: '${current.windSpeed.round()} km/j',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onPrimaryContainer;
    return Column(
      children: [
        Icon(icon, color: onColor),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: onColor)),
        Text(label, style: TextStyle(fontSize: 12, color: onColor)),
      ],
    );
  }
}
