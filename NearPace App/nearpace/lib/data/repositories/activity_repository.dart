import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/activity.dart';
import '../../domain/geo_point.dart';
import '../../domain/weather.dart';

/// Contract for activity persistence under `users/{uid}/activities/{id}`.
abstract interface class ActivityRepository {
  Stream<List<Activity>> watchActivities(String uid);
  Future<String> saveActivity(String uid, Activity activity);
  Future<void> deleteActivity(String uid, String activityId);
}

/// Cloud Firestore implementation of [ActivityRepository].
class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int maxRoutePoints = 250;

  CollectionReference<Map<String, dynamic>> _activitiesCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('activities');

  @override
  Stream<List<Activity>> watchActivities(String uid) {
    return _activitiesCol(uid)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                return _activityFromFirestore(doc.id, doc.data());
              })
              .toList(growable: false);
        });
  }

  @override
  Future<String> saveActivity(String uid, Activity activity) async {
    final cappedRoute = capRoute(activity.route, maxPoints: maxRoutePoints);
    final data = _activityToFirestore(activity, cappedRoute);

    // If ID already looks like a valid Firestore doc ID (not a local preview ID),
    // update or set with that ID; otherwise generate a new Firestore ID.
    final collection = _activitiesCol(uid);
    if (activity.id.isNotEmpty && !activity.id.startsWith('local-')) {
      await collection
          .doc(activity.id)
          .set(data)
          .timeout(const Duration(seconds: 6));
      return activity.id;
    } else {
      final docRef = await collection
          .add(data)
          .timeout(const Duration(seconds: 6));
      return docRef.id;
    }
  }

  @override
  Future<void> deleteActivity(String uid, String activityId) async {
    await _activitiesCol(uid).doc(activityId).delete();
  }

  /// Simplifies/downsamples GPS route to at most [maxPoints], preserving
  /// the exact start and end points.
  static List<GeoPointLite> capRoute(
    List<GeoPointLite> points, {
    int maxPoints = maxRoutePoints,
  }) {
    if (points.length <= maxPoints) return points;
    final step = (points.length - 1) / (maxPoints - 1);
    final result = <GeoPointLite>[points.first];
    for (var i = 1; i < maxPoints - 1; i++) {
      final index = (i * step).round().clamp(1, points.length - 2);
      result.add(points[index]);
    }
    result.add(points.last);
    return result;
  }

  /// Serializes an [Activity] into a Firestore document map using native [Timestamp].
  static Map<String, dynamic> _activityToFirestore(
    Activity activity,
    List<GeoPointLite> route,
  ) {
    return {
      'startedAt': Timestamp.fromDate(activity.startedAt.toUtc()),
      'endedAt': Timestamp.fromDate(activity.endedAt.toUtc()),
      'distanceM': activity.distanceM,
      'durationS': activity.durationS,
      'avgPaceSecPerKm': activity.avgPaceSecPerKm,
      'route': route.map((point) => point.toMap()).toList(growable: false),
      if (activity.weather != null)
        'weather': {
          'temperatureC': activity.weather!.temperatureC,
          'apparentC': activity.weather!.apparentC,
          'code': activity.weather!.code,
          'fetchedAt': Timestamp.fromDate(activity.weather!.fetchedAt.toUtc()),
        },
      'isPublic': activity.isPublic,
      if (activity.city != null) 'city': activity.city,
    };
  }

  /// Deserializes a Firestore document map supporting both [Timestamp] and ISO-8601 [String].
  static Activity _activityFromFirestore(String id, Map<String, dynamic> map) {
    final rawStarted = map['startedAt'];
    final DateTime startedAt;
    if (rawStarted is Timestamp) {
      startedAt = rawStarted.toDate().toLocal();
    } else if (rawStarted is String) {
      startedAt = DateTime.parse(rawStarted).toLocal();
    } else {
      startedAt = DateTime.now();
    }

    final rawEnded = map['endedAt'];
    final DateTime endedAt;
    if (rawEnded is Timestamp) {
      endedAt = rawEnded.toDate().toLocal();
    } else if (rawEnded is String) {
      endedAt = DateTime.parse(rawEnded).toLocal();
    } else {
      endedAt = startedAt;
    }

    final rawRoute = (map['route'] as List<dynamic>? ?? const []);
    final route = rawRoute
        .map((entry) => GeoPointLite.fromMap(entry as Map<String, dynamic>))
        .toList(growable: false);

    WeatherSnapshot? weather;
    final rawWeather = map['weather'] as Map<String, dynamic>?;
    if (rawWeather != null) {
      final rawFetched = rawWeather['fetchedAt'];
      final DateTime? fetchedAt;
      if (rawFetched is Timestamp) {
        fetchedAt = rawFetched.toDate().toLocal();
      } else if (rawFetched is String) {
        fetchedAt = DateTime.tryParse(rawFetched)?.toLocal();
      } else {
        fetchedAt = null;
      }
      if (fetchedAt != null) {
        weather = WeatherSnapshot(
          temperatureC: (rawWeather['temperatureC'] as num).toDouble(),
          apparentC: (rawWeather['apparentC'] as num).toDouble(),
          code: (rawWeather['code'] as num).toInt(),
          fetchedAt: fetchedAt,
        );
      }
    }

    return Activity(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceM: (map['distanceM'] as num?)?.toDouble() ?? 0.0,
      durationS: (map['durationS'] as num?)?.toInt() ?? 0,
      avgPaceSecPerKm: (map['avgPaceSecPerKm'] as num?)?.toDouble(),
      route: route,
      weather: weather,
      isPublic: (map['isPublic'] as bool?) ?? true,
      city: map['city'] as String?,
    );
  }
}

/// In-memory mock implementation of [ActivityRepository] for tests and local preview.
class MockActivityRepository implements ActivityRepository {
  MockActivityRepository({List<Activity>? initialActivities})
    : _activities = List<Activity>.from(initialActivities ?? const []),
      _controller = StreamController<List<Activity>>.broadcast();

  final List<Activity> _activities;
  final StreamController<List<Activity>> _controller;

  @override
  Stream<List<Activity>> watchActivities(String uid) {
    scheduleMicrotask(() {
      if (!_controller.isClosed) {
        _controller.add(List.unmodifiable(_activities));
      }
    });
    return _controller.stream;
  }

  @override
  Future<String> saveActivity(String uid, Activity activity) async {
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index >= 0) {
      _activities[index] = activity;
    } else {
      _activities.insert(0, activity);
    }
    _controller.add(List.unmodifiable(_activities));
    return activity.id;
  }

  @override
  Future<void> deleteActivity(String uid, String activityId) async {
    _activities.removeWhere((a) => a.id == activityId);
    _controller.add(List.unmodifiable(_activities));
  }

  void dispose() {
    _controller.close();
  }
}
