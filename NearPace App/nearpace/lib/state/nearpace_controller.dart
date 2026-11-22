import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../config/firebase_bootstrap.dart';
import '../data/repositories/activity_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/leaderboard_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/weather_repository.dart';
import '../domain/activity.dart';
import '../domain/geo_point.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/run_session.dart';
import '../domain/run_state.dart';
import '../domain/user_profile.dart';
import '../domain/weather.dart';
import '../services/location_tracking_service.dart';
import '../services/push_notification_service.dart';
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
/// Supports constructor injection of repositories and services while
/// keeping full backward compatibility with local mock preview mode.
class NearPaceController extends ChangeNotifier {
  NearPaceController({
    required this.firebaseStatus,
    DateTime? clockNow,
    bool startSignedIn = false,
    bool? isLocalPreview,
    this.authRepository,
    this.profileRepository,
    this.activityRepository,
    this.leaderboardRepository,
    this.weatherRepository,
    this.locationService,
    this.pushService,
  }) : _clockAnchor = clockNow,
       _isSignedIn = startSignedIn,
       _isLocalPreview = isLocalPreview ?? (firebaseStatus is! FirebaseReady),
       _profile = NearPaceMockData.defaultProfile(),
       _activities = NearPaceMockData.initialActivities(
         clockNow ?? DateTime.now(),
       ),
       _leaderboardBase = NearPaceMockData.initialLeaderboard(
         clockNow ?? DateTime.now(),
       ) {
    _initSubscriptions();
  }

  final FirebaseBootstrapStatus firebaseStatus;
  final DateTime? _clockAnchor;
  final bool _isLocalPreview;

  final AuthRepository? authRepository;
  final ProfileRepository? profileRepository;
  final ActivityRepository? activityRepository;
  final LeaderboardRepository? leaderboardRepository;
  final WeatherRepository? weatherRepository;
  final LocationTrackingService? locationService;
  final PushNotificationService? pushService;

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

  bool _isAuthBusy = false;
  bool get isAuthBusy => _isAuthBusy;

  String? _authError;
  String? get authError => _authError;

  /// True while running against local mock fixtures rather than live Firebase.
  bool get isLocalPreview => _isLocalPreview;

  UserProfile _profile;
  UserProfile get profile => _profile;

  // --- Activities & View States ---
  final List<Activity> _activities;
  List<Activity> get activities => List.unmodifiable(_activities);

  ViewLoadState _historyState = ViewLoadState.ready;
  ViewLoadState get historyState => _historyState;
  String? _historyError;
  String? get historyError => _historyError;

  bool _isSavingActivity = false;
  bool get isSavingActivity => _isSavingActivity;

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

  // --- Stream Subscriptions ---
  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;
  StreamSubscription<List<Activity>>? _activitiesSubscription;
  StreamSubscription<List<LeaderboardEntry>>? _leaderboardSubscription;
  StreamSubscription<ForegroundNotice>? _pushSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<GeoPointLite>? _positionSubscription;

  void _initSubscriptions() {
    if (_isLocalPreview) return;

    // Listen to Firebase auth changes.
    final authRepo = authRepository;
    if (authRepo != null) {
      _authSubscription = authRepo.authStateChanges().listen((uid) {
        if (uid != null && uid.isNotEmpty) {
          _isSignedIn = true;
          _subscribeToUserData(uid);
        } else {
          _unsubscribeUserData();
          _isSignedIn = false;
        }
        notifyListeners();
      });
    }

    // Listen to weekly leaderboard query.
    final lbRepo = leaderboardRepository;
    if (lbRepo != null) {
      _leaderboardSubscription = lbRepo
          .watchWeeklyLeaderboard(currentWeekKey)
          .listen(
            (entries) {
              _leaderboardBase.clear();
              _leaderboardBase.addAll(entries);
              _leaderboardState = ViewLoadState.ready;
              _leaderboardError = null;
              notifyListeners();
            },
            onError: (error) {
              _leaderboardState = ViewLoadState.error;
              _leaderboardError = error.toString();
              notifyListeners();
            },
          );
    }

    // Listen to push messages.
    final push = pushService;
    if (push != null) {
      _pushSubscription = push.foregroundMessages.listen((notice) {
        _activeNotice = notice;
        notifyListeners();
      });

      _tokenRefreshSubscription = push.onTokenRefresh.listen((token) {
        if (_isSignedIn && _profile.uid.isNotEmpty) {
          profileRepository?.updateFcmToken(_profile.uid, token);
        }
      });
    }
  }

  void _subscribeToUserData(String uid) {
    _profileSubscription?.cancel();
    final profRepo = profileRepository;
    if (profRepo != null) {
      _profileSubscription = profRepo.watchProfile(uid).listen((profile) {
        if (profile != null) {
          _profile = profile;
          notifyListeners();
        }
      });
    }

    _activitiesSubscription?.cancel();
    final actRepo = activityRepository;
    if (actRepo != null) {
      _activitiesSubscription = actRepo
          .watchActivities(uid)
          .listen(
            (list) {
              _activities.clear();
              _activities.addAll(list);
              _historyState = ViewLoadState.ready;
              _historyError = null;
              notifyListeners();
            },
            onError: (error) {
              _historyState = ViewLoadState.error;
              _historyError = error.toString();
              notifyListeners();
            },
          );
    }

    // Initialize Push Notifications if enabled.
    final push = pushService;
    if (push != null) {
      push.initializeAndGetToken().then((token) {
        if (token != null && token.isNotEmpty) {
          profileRepository?.updateFcmToken(uid, token);
        }
        push.subscribeToTopic('nearpace_updates');
      });
    }
  }

  void _unsubscribeUserData() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _activitiesSubscription?.cancel();
    _activitiesSubscription = null;
  }

  // --- Derived Weekly Metrics ---

  String get currentWeekKey => NearPaceFormatters.isoWeekKey(now);

  List<Activity> get weeklyActivities {
    final key = currentWeekKey;
    return _activities
        .where((a) => NearPaceFormatters.isoWeekKey(a.startedAt) == key)
        .toList(growable: false);
  }

  List<Activity> get weeklyPublicActivities =>
      weeklyActivities.where((a) => a.isPublic).toList(growable: false);

  double get weeklyDistanceMeters =>
      weeklyActivities.fold(0.0, (sum, a) => sum + a.distanceM);

  double get weeklyPublicDistanceMeters =>
      weeklyPublicActivities.fold(0.0, (sum, a) => sum + a.distanceM);

  Duration get weeklyDuration => Duration(
    seconds: weeklyActivities.fold(0, (sum, a) => sum + a.durationS),
  );

  String get currentLeaderboardCity {
    for (final a in weeklyActivities) {
      if (a.isPublic && a.city != null && a.city!.trim().isNotEmpty) {
        return a.city!.trim();
      }
    }
    return _profile.city.trim();
  }

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
    if (_profile.showOnLeaderboard &&
        !list.any((entry) => entry.uid == _profile.uid)) {
      list.add(
        LeaderboardEntry(
          uid: _profile.uid,
          displayName: _profile.displayName,
          city: currentLeaderboardCity,
          weekKey: currentWeekKey,
          distanceM: weeklyPublicDistanceMeters > 0
              ? weeklyPublicDistanceMeters
              : weeklyDistanceMeters,
          runCount: weeklyPublicActivities.isNotEmpty
              ? weeklyPublicActivities.length
              : weeklyActivities.length,
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

  // --- Authentication Actions ---

  Future<void> signIn({required String email, required String password}) async {
    _isAuthBusy = true;
    _authError = null;
    notifyListeners();

    try {
      final authRepo = authRepository;
      if (_isLocalPreview || authRepo == null) {
        signInLocalPreview(email: email);
      } else {
        final uid = await authRepo.signIn(email: email, password: password);
        final profRepo = profileRepository;
        final remoteProfile = await profRepo?.getProfile(uid);
        if (remoteProfile != null) {
          _profile = remoteProfile;
        } else {
          final newProfile = UserProfile(
            uid: uid,
            email: email.trim(),
            displayName: email.contains('@')
                ? email.split('@').first
                : 'Runner',
            city: '',
            showOnLeaderboard: false,
          );
          _profile = newProfile;
          await profRepo?.upsertProfile(newProfile, isNew: true);
        }
        _isSignedIn = true;
        _selectedTabIndex = 0;
        _subscribeToUserData(uid);
      }
    } catch (e) {
      _authError = e.toString();
      rethrow;
    } finally {
      _isAuthBusy = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String city,
  }) async {
    _isAuthBusy = true;
    _authError = null;
    notifyListeners();

    try {
      final authRepo = authRepository;
      if (_isLocalPreview || authRepo == null) {
        signUpLocalPreview(email: email, displayName: displayName, city: city);
      } else {
        final uid = await authRepo.signUp(email: email, password: password);
        final trimmedName = displayName.trim();
        final effectiveName = trimmedName.isNotEmpty
            ? trimmedName
            : (email.contains('@') ? email.split('@').first : 'Runner');
        final newProfile = UserProfile(
          uid: uid,
          email: email.trim(),
          displayName: effectiveName,
          city: city.trim(),
          showOnLeaderboard: false,
        );
        _profile = newProfile;
        try {
          await profileRepository?.upsertProfile(newProfile, isNew: true);
        } catch (_) {
          // If Firestore initial write times out, session still proceeds.
        }
        _isSignedIn = true;
        _selectedTabIndex = 0;
        _subscribeToUserData(uid);
      }
    } catch (e) {
      _authError = e.toString();
      rethrow;
    } finally {
      _isAuthBusy = false;
      notifyListeners();
    }
  }

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

  Future<void> signOut() async {
    _cancelRunTimer();
    _positionSubscription?.cancel();
    _activeSession = null;
    _runState = const RunIdle();
    _activeNotice = null;
    _isSignedIn = false;
    _selectedTabIndex = 0;

    _unsubscribeUserData();

    final authRepo = authRepository;
    if (!_isLocalPreview && authRepo != null) {
      try {
        await authRepo.signOut();
      } catch (_) {}
    }
    notifyListeners();
  }

  // --- Profile Actions ---

  Future<void> updateProfile({
    required String displayName,
    required String city,
  }) async {
    _profile = _profile.copyWith(
      displayName: displayName.trim(),
      city: city.trim(),
    );
    notifyListeners();

    final profRepo = profileRepository;
    if (!_isLocalPreview && profRepo != null) {
      await profRepo.updateIdentity(
        _profile.uid,
        displayName: displayName.trim(),
        city: city.trim(),
      );
      if (_profile.showOnLeaderboard) {
        await _syncLeaderboardEntry();
      }
    }
  }

  Future<void> setShowOnLeaderboard(bool value) async {
    if (_profile.showOnLeaderboard == value) return;
    _profile = _profile.copyWith(showOnLeaderboard: value);
    notifyListeners();

    final profRepo = profileRepository;
    if (!_isLocalPreview && profRepo != null) {
      await profRepo.setShowOnLeaderboard(_profile.uid, value);
      if (value) {
        await _syncLeaderboardEntry();
      } else {
        await leaderboardRepository?.deleteEntry(
          weekKey: currentWeekKey,
          uid: _profile.uid,
        );
      }
    }
  }

  Future<void> _syncLeaderboardEntry({String? runCity}) async {
    final lbRepo = leaderboardRepository;
    if (lbRepo == null) return;
    final targetCity = (runCity != null && runCity.trim().isNotEmpty)
        ? runCity.trim()
        : currentLeaderboardCity;

    final entry = LeaderboardEntry(
      uid: _profile.uid,
      displayName: _profile.displayName,
      city: targetCity,
      weekKey: currentWeekKey,
      distanceM: weeklyPublicDistanceMeters > 0
          ? weeklyPublicDistanceMeters
          : weeklyDistanceMeters,
      runCount: weeklyPublicActivities.isNotEmpty
          ? weeklyPublicActivities.length
          : weeklyActivities.length,
      updatedAt: now,
    );
    try {
      await lbRepo.upsertEntry(entry).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Leaderboard sync failure should not block run save
    }
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
    if (!_isLocalPreview && _profile.uid.isNotEmpty) {
      _subscribeToUserData(_profile.uid);
    }
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

  Future<LocationPermissionStatus> requestLocationPermission() async {
    final loc = locationService;
    if (loc != null && !_isLocalPreview) {
      final status = await loc.requestPermission();
      setLocationPermission(status);
      return status;
    }
    return _locationPermission;
  }

  Future<bool> openAppSettings() async {
    return await locationService?.openAppSettings() ?? false;
  }

  Future<bool> openLocationSettings() async {
    return await locationService?.openLocationSettings() ?? false;
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
    _positionSubscription?.cancel();
    _runState = const RunPreparing();
    notifyListeners();

    final locService = locationService;
    if (_isLocalPreview || locService == null) {
      if (acquireDelay > Duration.zero) {
        await Future<void>.delayed(acquireDelay);
      }
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
    } else {
      // Live device mode via LocationTrackingService
      final serviceEnabled = await locService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _runState = const RunFailed(
          'Location services are disabled on your device. Enable GPS in settings to record runs.',
        );
        notifyListeners();
        return;
      }

      final startedAt = DateTime.now();
      final session = RunSession(startedAt: startedAt);
      _activeSession = session;

      final completer = Completer<void>();
      _positionSubscription = locService.positionStream().listen(
        (point) {
          if (!completer.isCompleted) {
            completer.complete();
          }
          if (_activeSession != null && _runState is RunActive) {
            final now = DateTime.now();
            final accepted = _activeSession!.addSample(point, now);
            if (accepted) {
              notifyListeners();
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
          _runState = RunFailed('GPS stream error: $error');
          notifyListeners();
        },
      );

      try {
        final timeout = acquireDelay > Duration.zero
            ? acquireDelay
            : const Duration(seconds: 20);
        await completer.future.timeout(timeout);
        if (_runState is! RunPreparing) return;
        _runState = const RunActive(paused: false);
        _startRunTimer();
        notifyListeners();
      } catch (_) {
        if (_runState is RunPreparing) {
          _runState = const RunFailed(
            'Unable to acquire a reliable GPS fix. Move to an open outdoor area and try again.',
          );
          notifyListeners();
        }
      }
    }
  }

  void simulateGpsSignalLost() {
    _cancelRunTimer();
    _positionSubscription?.cancel();
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
    _positionSubscription?.cancel();
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
    _positionSubscription?.cancel();
    _positionSubscription = null;
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

    WeatherSnapshot? weather;
    final weatherRepo = weatherRepository;
    if (_isLocalPreview || weatherRepo == null) {
      weather = _weatherAvailableInPreview && route.isNotEmpty
          ? WeatherSnapshot(
              temperatureC: 27.6,
              apparentC: 29.9,
              code: 1,
              fetchedAt: endedAt,
            )
          : null;
    } else {
      if (route.isNotEmpty) {
        weather = await weatherRepo.fetchCurrentWeather(route.first);
      }
    }

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

  Future<void> saveActivity(Activity activity) async {
    final existingIndex = _activities.indexWhere((a) => a.id == activity.id);
    if (existingIndex >= 0) {
      _activities[existingIndex] = activity;
    } else {
      _activities.insert(0, activity);
    }
    notifyListeners();

    final actRepo = activityRepository;
    if (!_isLocalPreview && actRepo != null && _profile.uid.isNotEmpty) {
      _isSavingActivity = true;
      notifyListeners();
      try {
        final savedId = await actRepo.saveActivity(_profile.uid, activity);
        final idx = _activities.indexWhere((a) => a.id == activity.id);
        if (idx >= 0 && savedId != activity.id) {
          _activities[idx] = activity.copyWith(id: savedId);
        }
        if (activity.isPublic) {
          if (!_profile.showOnLeaderboard) {
            _profile = _profile.copyWith(showOnLeaderboard: true);
            profileRepository?.setShowOnLeaderboard(_profile.uid, true);
          }
          await _syncLeaderboardEntry(runCity: activity.city);
        } else if (_profile.showOnLeaderboard) {
          await _syncLeaderboardEntry();
        }
      } finally {
        _isSavingActivity = false;
        notifyListeners();
      }
    }
  }

  Future<void> deleteActivity(String id) async {
    _activities.removeWhere((a) => a.id == id);
    notifyListeners();

    final actRepo = activityRepository;
    if (!_isLocalPreview && actRepo != null && _profile.uid.isNotEmpty) {
      await actRepo.deleteActivity(_profile.uid, id);
      if (_profile.showOnLeaderboard) {
        await _syncLeaderboardEntry();
      }
    }
  }

  void _startRunTimer() {
    _runTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = _activeSession;
      final state = _runState;
      if (session == null || state is! RunActive) {
        _cancelRunTimer();
        return;
      }
      if (!state.paused && _isLocalPreview && _simulateGpsInPreview) {
        final loop = NearPaceMockData.simulationLoop();
        final tickTime = DateTime.now();
        final elapsedSec = session.elapsedAt(tickTime).inSeconds;
        if (elapsedSec > 0 && elapsedSec % 3 == 0) {
          final target = loop[_simIndex % loop.length];
          final prev = session.samples.isEmpty
              ? null
              : session.samples.last.point;
          if (prev != null) {
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
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _activitiesSubscription?.cancel();
    _leaderboardSubscription?.cancel();
    _pushSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
