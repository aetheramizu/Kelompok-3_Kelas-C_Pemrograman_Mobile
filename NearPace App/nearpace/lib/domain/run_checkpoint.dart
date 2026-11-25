import 'dart:convert';

import 'geo_point.dart';
import 'run_session.dart';

/// Persisted checkpoint snapshot for an in-flight [RunSession] to survive OS kills.
class RunCheckpoint {
  const RunCheckpoint({
    required this.startedAt,
    required this.isPaused,
    required this.pausedTotalMs,
    required this.pausedAt,
    required this.distanceM,
    required this.samples,
    required this.lastSavedAt,
  });

  factory RunCheckpoint.fromSession(
    RunSession session, {
    required bool isPaused,
    DateTime? lastSavedAt,
  }) {
    return RunCheckpoint(
      startedAt: session.startedAt,
      isPaused: isPaused,
      pausedTotalMs: session.pausedTotal.inMilliseconds,
      pausedAt: session.pausedAt,
      distanceM: session.distanceMeters,
      samples: session.samples,
      lastSavedAt: lastSavedAt ?? DateTime.now(),
    );
  }

  final DateTime startedAt;
  final bool isPaused;
  final int pausedTotalMs;
  final DateTime? pausedAt;
  final double distanceM;
  final List<RunSample> samples;
  final DateTime lastSavedAt;

  RunSession toSession() {
    return RunSession.restore(
      startedAt: startedAt,
      samples: samples,
      pausedTotal: Duration(milliseconds: pausedTotalMs),
      pausedAt: pausedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'startedAt': startedAt.toIso8601String(),
    'isPaused': isPaused,
    'pausedTotalMs': pausedTotalMs,
    'pausedAt': pausedAt?.toIso8601String(),
    'distanceM': distanceM,
    'lastSavedAt': lastSavedAt.toIso8601String(),
    'samples': samples
        .map(
          (s) => {
            'lat': s.point.latitude,
            'lng': s.point.longitude,
            'acc': s.point.accuracyM,
            'at': s.at.toIso8601String(),
          },
        )
        .toList(growable: false),
  };

  factory RunCheckpoint.fromMap(Map<String, dynamic> map) {
    final rawSamples = map['samples'] as List<dynamic>? ?? const [];
    final samples = rawSamples
        .map((raw) {
          final item = raw as Map<String, dynamic>;
          final lat = (item['lat'] as num).toDouble();
          final lng = (item['lng'] as num).toDouble();
          final acc = (item['acc'] as num?)?.toDouble();
          final at = DateTime.parse(item['at'] as String);
          return RunSample(
            point: GeoPointLite(
              latitude: lat,
              longitude: lng,
              accuracyM: acc,
              recordedAt: at,
            ),
            at: at,
          );
        })
        .toList(growable: false);

    return RunCheckpoint(
      startedAt: DateTime.parse(map['startedAt'] as String),
      isPaused: map['isPaused'] as bool? ?? false,
      pausedTotalMs: map['pausedTotalMs'] as int? ?? 0,
      pausedAt: map['pausedAt'] != null
          ? DateTime.tryParse(map['pausedAt'] as String)
          : null,
      distanceM: (map['distanceM'] as num?)?.toDouble() ?? 0.0,
      samples: samples,
      lastSavedAt: DateTime.parse(
        map['lastSavedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory RunCheckpoint.fromJson(String jsonStr) =>
      RunCheckpoint.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}
