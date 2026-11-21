import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../config/firebase_bootstrap.dart';
import '../domain/activity.dart';
import '../domain/geo_point.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/run_session.dart';
import '../domain/run_state.dart';
import '../domain/user_profile.dart';
import '../domain/weather.dart';
import '../utils/formatters.dart';
import 'mock_data.dart';

/// Foreground location permission state modeled for the recording flow.
enum LocationPermissionStatus { notRequested, granted, denied, deniedForever }

/// UI view load state for lists and async panels.
enum ViewLoadState { ready, loading, error }

/// In-app banner payload matching the MVP foreground FCM banner requirement.
@immutable
class ForegroundNotice {
  const ForegroundNotice({
    required this.title,
    required this.body,
    required this.receivedAt,
    this.topic = 'nearpace_updates',
  });

  final String title;
  final String body;
  final DateTime receivedAt;
  final String topic;
}

/// Central UI state controller for the NearPace MVP frontend.
///
/// Designed around `ChangeNotifier` so future Firebase Auth, Firestore,
/// Geolocator, Open-Meteo, and FCM services can plug into the same contract
/// without rewriting screens.
class NearPaceController extends ChangeNotifier {
  NearPaceController({
    required this.firebaseStatus,
    DateTime? clockNow,
    bool startSignedIn = false,
  }) : _clockAnchor = clockNow,
       _isSignedIn = startSignedIn,
       _profile = NearPaceMockData.defaultProfile(),
       _activities = NearPaceMockData.initialActivities(
         clockNow ?? DateTime.now(),
       ),
       _leaderboardBase = NearPaceMockData.initialLeaderboard(
         clockNow ?? DateTime.now(),
       );

  final FirebaseBootstrapStatus firebaseStatus;
  final DateTime? _clockAnchor;

  DateTime get now => _clockAnchor ?? DateTime.now();

  // --- Theme & App Shell ---
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  ForegroundNotice? _activeNotice;
  ForegroundNotice? get activeNotice => _activeNotice;

  // --- Auth & Profile ---
  bool _isSignedIn;
  bool get isSignedIn => _isSignedIn;

  /// True while running against local mock fixtures rather than live Firebase.
  bool get isLocalPreview => true;

  UserProfile _profile;
  UserProfile get profile => _profile;

  // --- Activities & View States ---
  final List<Activity> _activities;
  List<Activity> get activities => List.unmodifiable(_activities);

  ViewLoadState _historyState = ViewLoadState.ready;
  ViewLoadState get historyState => _historyState;
  String? _historyError;
  String? get historyError => _historyError;

  // --- Leaderboard ---
  final List<LeaderboardEntry> _leaderboardBase;
  String? _selectedCity;
  String? get selectedCity => _selectedCity;

  ViewLoadState _leaderboardState = ViewLoadState.ready;
  ViewLoadState get leaderboardState => _leaderboardState;
  String? _leaderboardError;
  String? get leaderboardError => _leaderboardError;

  // --- Recording Session ---
  RunState _runState = const RunIdle();
  RunState get runState => _runState;

  LocationPermissionStatus _locationPermission =
      LocationPermissionStatus.notRequested;
  LocationPermissionStatus get locationPermission => _locationPermission;

  RunSession? _activeSession;
  RunSession? get activeSession => _activeSession;

  Timer? _runTickTimer;
  int _simIndex = 0;
  bool _simulateGpsInPreview = true;
  bool get simulateGpsInPreview => _simulateGpsInPreview;

  bool _weatherAvailableInPreview = true;
  bool get weatherAvailableInPreview => _weatherAvailableInPreview;

  // --- Derived Weekly Metrics ---

  String get currentWeekKey => NearPaceFormatters.isoWeekKey(now);

  List<Activity> get weeklyActivities {
    final key = currentWeekKey;
    return _activities
        .where((a) => NearPaceFormatters.isoWeekKey(a.startedAt) == key)
        .toList(growable: false);
  }

  double get weeklyDistanceMeters =>
      weeklyActivities.fold(0.0, (sum, a) => sum + a.distanceM);

  Duration get weeklyDuration => Duration(
    seconds: weeklyActivities.fold(0, (sum, a) => sum + a.durationS),
  );

  double? get weeklyAvgPaceSecPerKm {
    final distanceM = weeklyDistanceMeters;
    if (distanceM < 50) return null;
    return weeklyDuration.inSeconds / (distanceM / 1000.0);
  }

  /// Distance in metres for each day of the current ISO week (index 0 = Monday).
  List<double> get weeklyDailyDistancesMeters {
    final totals = List<double>.filled(7, 0);
    for (final activity in weeklyActivities) {
      final index = (activity.startedAt.toLocal().weekday - DateTime.monday)
          .clamp(0, 6);
      totals[index] += activity.distanceM;
    }
    return totals;
  }

  double get totalDistanceMeters =>
      _activities.fold(0.0, (sum, a) => sum + a.distanceM);

  // --- Derived Leaderboard ---

  List<LeaderboardEntry> get allLeaderboardEntries {
    final list = List<LeaderboardEntry>.from(_leaderboardBase);
    if (_profile.showOnLeaderboard) {
      list.add(
        LeaderboardEntry(
          uid: _profile.uid,
          displayName: _profile.displayName,
          city: _profile.city,
          weekKey: currentWeekKey,
          distanceM: weeklyDistanceMeters,
          runCount: weeklyActivities.length,
          updatedAt: now,
        ),
      );
    }
    list.sort((a, b) => b.distanceM.compareTo(a.distanceM));
    return list;
  }

  List<String> get availableCities {
    final cities = <String>{};
    for (final entry in allLeaderboardEntries) {
      if (entry.city.trim().isNotEmpty) {
        cities.add(entry.city.trim());
      }
    }
    if (_profile.city.trim().isNotEmpty) {
      cities.add(_profile.city.trim());
    }
    final sorted = cities.toList()..sort();
    return sorted;
  }

  List<LeaderboardEntry> get filteredLeaderboardEntries {
    final entries = allLeaderboardEntries;
    final city = _selectedCity;
    if (city == null || city.isEmpty) return entries;
    return entries
        .where((e) => e.city.toLowerCase() == city.toLowerCase())
        .toList(growable: false);
  }

  // --- Navigation & Appearance Actions ---

  void setTabIndex(int index) {
    if (index == _selectedTabIndex) return;
    _selectedTabIndex = index;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
  }

  // --- Auth Preview Actions ---

  void signInLocalPreview({required String email}) {
    final trimmed = email.trim();
    final inferredName = trimmed.contains('@')
        ? trimmed.split('@').first
        : _profile.displayName;
    final prettyName = inferredName.isEmpty
        ? _profile.displayName
        : inferredName[0].toUpperCase() + inferredName.substring(1);
    _profile = UserProfile(
      uid: _profile.uid,
      email: trimmed.isEmpty ? _profile.email : trimmed,
      displayName: _profile.email == trimmed
          ? _profile.displayName
          : prettyName,
      city: _profile.city,
      showOnLeaderboard: _profile.showOnLeaderboard,
    );
    _isSignedIn = true;
    _selectedTabIndex = 0;
    notifyListeners();
  }

  void signUpLocalPreview({
    required String email,
    required String displayName,
    required String city,
  }) {
    _profile = UserProfile(
      uid: 'preview-${DateTime.now().millisecondsSinceEpoch}',
      email: email.trim(),
      displayName: displayName.trim(),
      city: city.trim(),
      showOnLeaderboard: false,
    );
    _isSignedIn = true;
    _selectedTabIndex = 0;
    notifyListeners();
  }

  void enterQuickPreview() {
    _isSignedIn = true;
    _selectedTabIndex = 0;
    notifyListeners();
  }

  void signOut() {
    _cancelRunTimer();
    _activeSession = null;
    _runState = const RunIdle();
    _activeNotice = null;
    _isSignedIn = false;
    _selectedTabIndex = 0;
    notifyListeners();
  }

  // --- Profile Actions ---

  void updateProfile({required String displayName, required String city}) {
    _profile = _profile.copyWith(
      displayName: displayName.trim(),
      city: city.trim(),
    );
    notifyListeners();
  }

  void setShowOnLeaderboard(bool value) {
    if (_profile.showOnLeaderboard == value) return;
    _profile = _profile.copyWith(showOnLeaderboard: value);
    notifyListeners();
  }

  // --- Foreground Notification Banner Preview (FCM MVP UI) ---

  void triggerPreviewNotification({
    String title = 'Weekly summary ready',
    String body = 'You have logged runs this week on NearPace.',
  }) {
    _activeNotice = ForegroundNotice(title: title, body: body, receivedAt: now);
    notifyListeners();
  }

  void dismissNotification() {
    if (_activeNotice == null) return;
    _activeNotice = null;
    notifyListeners();
  }

  // --- History & Leaderboard View State Helpers ---

  void setSelectedCity(String? city) {
    if (_selectedCity == city) return;
    _selectedCity = city;
    notifyListeners();
  }

  void setHistoryState(ViewLoadState state, {String? error}) {
    _historyState = state;
    _historyError = error;
    notifyListeners();
  }

  void setLeaderboardState(ViewLoadState state, {String? error}) {
    _leaderboardState = state;
    _leaderboardError = error;
    notifyListeners();
  }

  void retryHistory() {
    _historyState = ViewLoadState.ready;
    _historyError = null;
    notifyListeners();
  }

  void retryLeaderboard() {
    _leaderboardState = ViewLoadState.ready;
    _leaderboardError = null;
    notifyListeners();
  }

  // --- Recording & Permission Flow ---

  void setLocationPermission(LocationPermissionStatus status) {
    _locationPermission = status;
    if (status == LocationPermissionStatus.denied) {
      _runState = const RunFailed(
        'Location permission was denied. Allow location access while using '
        'NearPace to record GPS distance and pace.',
      );
    } else if (status == LocationPermissionStatus.deniedForever) {
      _runState = const RunFailed(
        'Location access is permanently denied. Enable location permission for '
        'NearPace in Android system settings to record runs.',
      );
    } else if (status == LocationPermissionStatus.granted &&
        _runState is RunFailed) {
      _runState = const RunIdle();
    }
    notifyListeners();
  }

  void setSimulateGpsInPreview(bool enabled) {
    _simulateGpsInPreview = enabled;
    notifyListeners();
  }

  void setWeatherAvailableInPreview(bool available) {
    _weatherAvailableInPreview = available;
    notifyListeners();
  }

  /// Begins acquiring a GPS fix and transitions into active recording.
  Future<void> startRecording({
    Duration acquireDelay = const Duration(milliseconds: 650),
  }) async {
    if (_locationPermission != LocationPermissionStatus.granted) {
      _runState = const RunFailed(
        'Location permission is required before starting a run.',
      );
      notifyListeners();
      return;
    }

    _cancelRunTimer();
    _runState = const RunPreparing();
    notifyListeners();

    if (acquireDelay > Duration.zero) {
      await Future<void>.delayed(acquireDelay);
    }
    // Guard in case the runner backed out or cancelled during GPS lock.
    if (_runState is! RunPreparing) return;

    final startedAt = DateTime.now();
    final session = RunSession(startedAt: startedAt);
    _activeSession = session;
    _simIndex = 0;

    if (_simulateGpsInPreview) {
      final points = NearPaceMockData.simulationLoop();
      session.addSample(points.first, startedAt);
      _simIndex = 1;
    }

    _runState = const RunActive(paused: false);
    _startRunTimer();
    notifyListeners();
  }

  void simulateGpsSignalLost() {
    _cancelRunTimer();
    _runState = const RunFailed(
      'Unable to acquire a reliable GPS fix. Move to an open outdoor area and '
      'try again.',
    );
    notifyListeners();
  }

  void pauseRecording() {
    final session = _activeSession;
    if (session == null || _runState is! RunActive) return;
    session.pause(DateTime.now());
    _runState = const RunActive(paused: true);
    notifyListeners();
  }

  void resumeRecording() {
    final session = _activeSession;
    if (session == null || _runState is! RunActive) return;
    session.resume(DateTime.now());
    _runState = const RunActive(paused: false);
    notifyListeners();
  }

  void resetRecording() {
    _cancelRunTimer();
    _activeSession = null;
    _runState = const RunIdle();
    notifyListeners();
  }

  /// Stops the active run and builds an unsaved [Activity] for the result screen.
  Future<Activity?> finishRecording({
    Duration finalizeDelay = const Duration(milliseconds: 250),
  }) async {
    final session = _activeSession;
    if (session == null) return null;

    _cancelRunTimer();
    _runState = const RunStopping();
    notifyListeners();

    if (finalizeDelay > Duration.zero) {
      await Future<void>.delayed(finalizeDelay);
    }

    final endedAt = DateTime.now();
    if (session.isPaused) {
      session.resume(endedAt);
    }
    final elapsed = session.elapsedAt(endedAt);
    final distanceM = session.distanceMeters;
    final avgPace = session.paceSecPerKmAt(endedAt);
    final route = session.route;

    final weather = _weatherAvailableInPreview && route.isNotEmpty
        ? WeatherSnapshot(
            temperatureC: 27.6,
            apparentC: 29.9,
            code: 1,
            fetchedAt: endedAt,
          )
        : null;

    final activity = Activity(
      id: 'local-${endedAt.millisecondsSinceEpoch}',
      startedAt: session.startedAt,
      endedAt: endedAt,
      distanceM: distanceM,
      durationS: elapsed.inSeconds,
      avgPaceSecPerKm: avgPace,
      route: route,
      weather: weather,
    );

    _activeSession = null;
    _runState = const RunIdle();
    notifyListeners();
    return activity;
  }

  void saveActivity(Activity activity) {
    final existingIndex = _activities.indexWhere((a) => a.id == activity.id);
    if (existingIndex >= 0) {
      _activities[existingIndex] = activity;
    } else {
      _activities.insert(0, activity);
    }
    notifyListeners();
  }

  void deleteActivity(String id) {
    _activities.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void _startRunTimer() {
    _runTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = _activeSession;
      final state = _runState;
      if (session == null || state is! RunActive) {
        _cancelRunTimer();
        return;
      }
      if (!state.paused && _simulateGpsInPreview) {
        final loop = NearPaceMockData.simulationLoop();
        final tickTime = DateTime.now();
        // Add a realistic ~8-15m forward step every 3 seconds (~4:30-5:30/km).
        final elapsedSec = session.elapsedAt(tickTime).inSeconds;
        if (elapsedSec > 0 && elapsedSec % 3 == 0) {
          final target = loop[_simIndex % loop.length];
          final prev = session.samples.isEmpty
              ? null
              : session.samples.last.point;
          if (prev != null) {
            // Interpolate ~14m step toward next loop waypoint so speed stays
            // strictly inside RunSession.maxSpeedMps.
            final dist = prev.distanceTo(target);
            if (dist <= 16) {
              session.addSample(target, tickTime);
              _simIndex++;
            } else {
              final ratio = 14.0 / dist;
              final step = GeoPointLite(
                latitude:
                    prev.latitude + (target.latitude - prev.latitude) * ratio,
                longitude:
                    prev.longitude +
                    (target.longitude - prev.longitude) * ratio,
                accuracyM: 6.5,
                recordedAt: tickTime,
              );
              session.addSample(step, tickTime);
            }
          } else {
            session.addSample(target, tickTime);
            _simIndex++;
          }
        }
      }
      notifyListeners();
    });
  }

  void _cancelRunTimer() {
    _runTickTimer?.cancel();
    _runTickTimer = null;
  }

  @override
  void dispose() {
    _cancelRunTimer();
    super.dispose();
  }
}
