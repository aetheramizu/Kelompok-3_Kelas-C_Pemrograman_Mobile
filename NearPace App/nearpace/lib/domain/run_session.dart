import 'geo_point.dart';

/// One accepted GPS sample with the moment it was received.
class RunSample {
  const RunSample({required this.point, required this.at});

  final GeoPointLite point;
  final DateTime at;
}

/// Accumulates GPS samples into distance, elapsed time and pace.
///
/// This is plain Dart: it can be unit-tested without a device or Firebase.
/// It deliberately ignores very inaccurate fixes and implausible jumps instead
/// of pretending that every coordinate is trustworthy.
class RunSession {
  RunSession({required this.startedAt});

  /// Restores an in-flight session from a persisted checkpoint.
  RunSession.restore({
    required this.startedAt,
    required List<RunSample> samples,
    this._pausedTotal = Duration.zero,
    this._pausedAt,
    this._rejectedSamples = 0,
  }) {
    _samples.addAll(samples);
  }

  /// Fixes with a reported accuracy worse than this are ignored.
  static const double maxAccuracyM = 35;

  /// Segments implying a faster speed than this are treated as GPS jumps.
  static const double maxSpeedMps = 12; // ~43 km/h

  final DateTime startedAt;
  final List<RunSample> _samples = [];

  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedAt;
  int _rejectedSamples = 0;

  List<RunSample> get samples => List.unmodifiable(_samples);
  List<GeoPointLite> get route =>
      _samples.map((sample) => sample.point).toList(growable: false);
  int get acceptedSamples => _samples.length;
  int get rejectedSamples => _rejectedSamples;
  bool get isPaused => _pausedAt != null;
  DateTime? get pausedAt => _pausedAt;
  Duration get pausedTotal => _pausedTotal;
  bool get hasEnoughData => _samples.length >= 2;

  /// Adds a fix and reports whether it was accepted.
  bool addSample(GeoPointLite point, DateTime at) {
    if (_pausedAt != null) return false;
    final accuracy = point.accuracyM;
    if (accuracy != null && accuracy > maxAccuracyM) {
      _rejectedSamples++;
      return false;
    }

    final previous = _samples.isEmpty ? null : _samples.last;
    if (previous != null) {
      final seconds = at.difference(previous.at).inMilliseconds / 1000;
      if (seconds <= 0) {
        _rejectedSamples++;
        return false;
      }
      final segment = previous.point.distanceTo(point);
      // Sub-metre movement is jitter, not progress.
      if (segment < 1.5) return false;
      if (segment / seconds > maxSpeedMps) {
        _rejectedSamples++;
        return false;
      }
    }

    _samples.add(RunSample(point: point, at: at));
    return true;
  }

  void pause(DateTime at) {
    if (_pausedAt != null) return;
    _pausedAt = at;
  }

  void resume(DateTime at) {
    final pausedAt = _pausedAt;
    if (pausedAt == null) return;
    _pausedTotal += at.difference(pausedAt);
    _pausedAt = null;
  }

  Duration elapsedAt(DateTime now) {
    var end = now;
    final pausedAt = _pausedAt;
    if (pausedAt != null) end = pausedAt;
    final elapsed = end.difference(startedAt) - _pausedTotal;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  double get distanceMeters {
    var total = 0.0;
    for (var i = 1; i < _samples.length; i++) {
      total += _samples[i - 1].point.distanceTo(_samples[i].point);
    }
    return total;
  }

  /// Seconds per kilometre, or null when the run is too short to be meaningful.
  double? paceSecPerKmAt(DateTime now) {
    final distance = distanceMeters;
    if (distance < 50) return null;
    return elapsedAt(now).inMilliseconds / 1000 / (distance / 1000);
  }
}
