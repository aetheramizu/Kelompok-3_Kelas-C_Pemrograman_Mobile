import 'package:flutter/material.dart';
import 'package:weather/models/weather_code.dart';
import 'package:weather/models/weather_data.dart';
import 'package:weather/ui/widgets/formatters.dart';
import 'package:weather/ui/widgets/weather_icon.dart';

class DailyList extends StatelessWidget {
  const DailyList({super.key, required this.days});

  final List<DailyForecast> days;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${days.length} Hari ke Depan',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < days.length; i++)
                _DayRow(day: days[i], isToday: i == 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.isToday});

  final DailyForecast day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(weatherIcon(day.weatherCode)),
      title: Text(isToday ? 'Hari ini' : formatDay(day.date)),
      subtitle: Text(
          '${describeWeatherCode(day.weatherCode)} \u2022 hujan ${day.precipitationProbability}%'),
      trailing: Text(
        '${day.temperatureMin.round()}\u00B0 / ${day.temperatureMax.round()}\u00B0',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
