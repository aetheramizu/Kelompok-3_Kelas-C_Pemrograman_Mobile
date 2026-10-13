import 'package:flutter/material.dart';
import 'package:weather/models/weather_data.dart';
import 'package:weather/ui/widgets/formatters.dart';
import 'package:weather/ui/widgets/weather_icon.dart';

class HourlyList extends StatelessWidget {
  const HourlyList({super.key, required this.hours});

  final List<HourlyForecast> hours;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('24 Jam ke Depan',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: hours.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _HourItem(hour: hours[index]),
          ),
        ),
      ],
    );
  }
}

class _HourItem extends StatelessWidget {
  const _HourItem({required this.hour});

  final HourlyForecast hour;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatHour(hour.time)),
            Icon(weatherIcon(hour.weatherCode, isDay: hour.isDay)),
            Text('${hour.temperature.round()}\u00B0',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${hour.precipitationProbability}%',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
