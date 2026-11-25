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
    this.isPublic = true,
    this.city,
    this.pendingSync = false,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceM;
  final int durationS;
  final double? avgPaceSecPerKm;
  final List<GeoPointLite> route;
  final WeatherSnapshot? weather;
  final bool isPublic;
  final String? city;
  final bool pendingSync;

  double get distanceKm => distanceM / 1000;

  Duration get duration => Duration(seconds: durationS);

  bool get hasRoute => route.length >= 2;

  Activity copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    double? distanceM,
    int? durationS,
    double? avgPaceSecPerKm,
    List<GeoPointLite>? route,
    WeatherSnapshot? weather,
    bool? isPublic,
    String? city,
    bool? pendingSync,
  }) => Activity(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    distanceM: distanceM ?? this.distanceM,
    durationS: durationS ?? this.durationS,
    avgPaceSecPerKm: avgPaceSecPerKm ?? this.avgPaceSecPerKm,
    route: route ?? this.route,
    weather: weather ?? this.weather,
    isPublic: isPublic ?? this.isPublic,
    city: city ?? this.city,
    pendingSync: pendingSync ?? this.pendingSync,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'distanceM': distanceM,
    'durationS': durationS,
    'avgPaceSecPerKm': avgPaceSecPerKm,
    'route': route.map((point) => point.toMap()).toList(),
    if (weather != null) 'weather': weather!.toMap(),
    'isPublic': isPublic,
    if (city != null) 'city': city,
    'pendingSync': pendingSync,
  };

  static Activity fromMap(dynamic first, [dynamic second]) {
    final String id;
    final Map<String, dynamic> map;
    if (first is String && second is Map<String, dynamic>) {
      id = first;
      map = second;
    } else if (first is Map<String, dynamic>) {
      map = first;
      id = (second is String ? second : null) ?? (map['id'] as String? ?? '');
    } else {
      throw ArgumentError('Invalid arguments to Activity.fromMap');
    }
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
      isPublic: (map['isPublic'] as bool?) ?? true,
      city: map['city'] as String?,
      pendingSync: (map['pendingSync'] as bool?) ?? false,
    );
  }
}
