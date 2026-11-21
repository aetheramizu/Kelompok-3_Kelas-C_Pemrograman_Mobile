import 'geo_point.dart';
import 'weather.dart';

/// A saved NearPace run. Stored at `users/{uid}/activities/{id}`.
class Activity {
  const Activity({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceM,
    required this.durationS,
    required this.avgPaceSecPerKm,
    required this.route,
    this.weather,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceM;
  final int durationS;
  final double? avgPaceSecPerKm;
  final List<GeoPointLite> route;
  final WeatherSnapshot? weather;

  double get distanceKm => distanceM / 1000;

  Duration get duration => Duration(seconds: durationS);

  bool get hasRoute => route.length >= 2;

  Activity copyWith({String? id, WeatherSnapshot? weather}) => Activity(
        id: id ?? this.id,
        startedAt: startedAt,
        endedAt: endedAt,
        distanceM: distanceM,
        durationS: durationS,
        avgPaceSecPerKm: avgPaceSecPerKm,
        route: route,
        weather: weather ?? this.weather,
      );

  Map<String, dynamic> toMap() => {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'distanceM': distanceM,
        'durationS': durationS,
        'avgPaceSecPerKm': avgPaceSecPerKm,
        'route': route.map((point) => point.toMap()).toList(),
        if (weather != null) 'weather': weather!.toMap(),
      };

  static Activity fromMap(String id, Map<String, dynamic> map) {
    final rawRoute = (map['route'] as List<dynamic>? ?? const []);
    return Activity(
      id: id,
      startedAt: DateTime.parse(map['startedAt'] as String).toLocal(),
      endedAt: DateTime.parse(map['endedAt'] as String).toLocal(),
      distanceM: (map['distanceM'] as num).toDouble(),
      durationS: (map['durationS'] as num).toInt(),
      avgPaceSecPerKm: (map['avgPaceSecPerKm'] as num?)?.toDouble(),
      route: rawRoute
          .map((entry) => GeoPointLite.fromMap(entry as Map<String, dynamic>))
          .toList(growable: false),
      weather: WeatherSnapshot.fromMap(map['weather'] as Map<String, dynamic>?),
    );
  }
}
