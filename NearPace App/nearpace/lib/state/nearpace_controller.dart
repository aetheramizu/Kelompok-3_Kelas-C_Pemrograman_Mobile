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
import '../domain/run_checkpoint.dart';
import '../domain/run_reminder.dart';
import '../domain/run_session.dart';
import '../domain/run_state.dart';
import '../domain/user_profile.dart';
import '../domain/weather.dart';
import '../services/connectivity_service.dart';
import '../services/location_tracking_service.dart';
import '../services/pending_sync_storage.dart';
import '../services/push_notification_service.dart';
import '../services/run_checkpoint_service.dart';
import '../services/run_foreground_service.dart';
import '../services/run_reminder_service.dart';
import '../services/sync_coordinator.dart';
import '../services/weather_cache_service.dart';
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
    bool? isAuthBootstrapped,
    this.authRepository,
    this.profileRepository,
    this.activityRepository,
    this.leaderboardRepository,
    this.weatherRepository,
    this.locationService,
    this.pushService,
    this.reminderService,
    this.foregroundService,
    this.checkpointService,
    this.pendingSyncStorage,
    this.weatherCacheService,
    this.connectivityService,
    SyncCoordinator? syncCoordinator,
  }) : _clockAnchor = clockNow,
       _isSignedIn = startSignedIn,
       _isLocalPreview = isLocalPreview ?? (firebaseStatus is! FirebaseReady),
       _isAuthBootstrapped =
           isAuthBootstrapped ??
           (startSignedIn
               ? true
               : (isLocalPreview ?? (firebaseStatus is! FirebaseReady))),
       _profile = NearPaceMockData.defaultProfile(),
       _activities = NearPaceMockData.initialActivities(
         clockNow ?? DateTime.now(),
       ),
       _leaderboardBase = NearPaceMockData.initialLeaderboard(
         clockNow ?? DateTime.now(),
       ) {
    _initForegroundService();
    _initSubscriptions();
    _checkInitialLocationPermission();
    _initSyncCoordinator(syncCoordinator);
    _loadPendingActivities();
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
  final RunReminderService? reminderService;
  final RunForegroundService? foregroundService;
  final RunCheckpointService? checkpointService;
  final PendingSyncStorage? pendingSyncStorage;
  final WeatherCacheService? weatherCacheService;
  final ConnectivityService? connectivityService;

  SyncCoordinator? _syncCoordinator;
  SyncCoordinator? get syncCoordinator => _syncCoordinator;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  bool _isSyncingActivities = false;
  bool get isSyncingActivities => _isSyncingActivities;

  int get pendingSyncCount => _activities.where((a) => a.pendingSync).length;

  RunReminder? _lastSyncedReminder;
  int _tickCount = 0;

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

  bool _isAuthBootstrapped;
  bool get isAuthBootstrapped => _isAuthBootstrapped;

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

  void _initForegroundService() {
    foregroundService?.initialize();
    foregroundService?.setActionListener(_handleForegroundAction);
  }

  void _handleForegroundAction(String action) {
    switch (action) {
      case 'pause':
        pauseRecording();
        break;
      case 'continue':
        resumeRecording();
        break;
      case 'stop':
        if (_runState is RunActive) {
          pauseRecording();
        }
        break;
    }
  }

  void _initSyncCoordinator(SyncCoordinator? custom) {
    if (custom != null) {
      _syncCoordinator = custom;
    } else if (connectivityService != null) {
      _syncCoordinator = NearPaceSyncCoordinator(
        connectivityService: connectivityService!,
        onSyncRequested: () => syncPendingActivities(),
      );
    }
    _syncCoordinator?.isOnlineStream.listen((online) {
      _isOffline = !online;
      notifyListeners();
    });
    connectivityService
        ?.checkOnline()
        .then((online) {
          _isOffline = !online;
          notifyListeners();
        })
        .catchError((_) {});
  }

  Future<void> _loadPendingActivities() async {
    final storage = pendingSyncStorage;
    if (storage == null) return;
    try {
      final pending = await storage.getPendingActivities();
      for (final act in pending) {
        final idx = _activities.indexWhere((a) => a.id == act.id);
        if (idx >= 0) {
          _activities[idx] = act;
        } else {
          _activities.insert(0, act);
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _mergePendingActivities() async {
    final storage = pendingSyncStorage;
    if (storage == null) return;
    try {
      final pending = await storage.getPendingActivities();
      for (final act in pending) {
        final idx = _activities.indexWhere((a) => a.id == act.id);
        if (idx >= 0) {
          _activities[idx] = act;
        } else {
          _activities.insert(0, act);
        }
      }
    } catch (_) {}
  }

  void setOffline(bool offline) {
    _isOffline = offline;
    notifyListeners();
  }

  Future<void> preCacheWeatherForecast(GeoPointLite location) async {
    if (_isOffline) return;
    await weatherRepository?.preCacheHourlyForecast(location);
  }

  void _checkInitialLocationPermission() {
    locationService
        ?.checkPermission()
        .then((status) {
          _locationPermission = status;
          notifyListeners();
        })
        .catchError((_) {});
  }

  Future<LocationPermissionStatus> checkLocationPermission() async {
    final locService = locationService;
    if (locService != null) {
      final status = await locService.checkPermission();
      _locationPermission = status;
      notifyListeners();
      return status;
    }
    return _locationPermission;
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveActiveCheckpoint();
    }
  }

  void _saveActiveCheckpoint() {
    final session = _activeSession;
    final chkService = checkpointService;
    if (session == null || chkService == null || _runState is! RunActive) {
      return;
    }
    final checkpoint = RunCheckpoint.fromSession(
      session,
      isPaused: (_runState as RunActive).paused,
    );
    unawaited(chkService.saveCheckpoint(checkpoint));
  }

  Future<void> _restoreCheckpointIfAny() async {
    final chkService = checkpointService;
    if (chkService == null) return;
    try {
      final checkpoint = await chkService.loadCheckpoint();
      if (checkpoint == null) return;
      if (DateTime.now().difference(checkpoint.lastSavedAt).inHours > 24) {
        await chkService.clearCheckpoint();
        return;
      }
      final session = checkpoint.toSession();
      _activeSession = session;
      _runState = RunActive(paused: checkpoint.isPaused);
      _startRunTimer();
      _updateForegroundNotification();
      if (!checkpoint.isPaused) {
        _listenToDevicePositionStream();
      }
      notifyListeners();
    } catch (_) {}
  }

  void _updateForegroundNotification() {
    final session = _activeSession;
    final fg = foregroundService;
    if (session == null || fg == null || _runState is! RunActive) return;
    final now = DateTime.now();
    final elapsed = session.elapsedAt(now);
    final pace = session.paceSecPerKmAt(now);
    final isPaused = (_runState as RunActive).paused;

    final title = isPaused ? 'NearPace (Paused)' : 'NearPace (Running)';
    final text =
        '${NearPaceFormatters.durationClock(elapsed)} • ${NearPaceFormatters.distanceKmValue(session.distanceMeters)} km • ${NearPaceFormatters.paceValue(pace)}/km';

    fg.update(title: title, text: text, isPaused: isPaused);
  }

  void _listenToDevicePositionStream() {
    final locService = locationService;
    if (locService == null || _isLocalPreview) return;
    _positionSubscription?.cancel();
    _positionSubscription = locService.positionStream().listen(
      (point) {
        if (_activeSession != null && _runState is RunActive) {
          final now = DateTime.now();
          final accepted = _activeSession!.addSample(point, now);
          if (accepted) {
            notifyListeners();
          }
        }
      },
      onError: (error) {
        _runState = RunFailed('GPS stream error: $error');
        notifyListeners();
      },
    );
  }

  void _initSubscriptions() {
    if (_isLocalPreview) {
      if (_isSignedIn) {
        unawaited(_restoreCheckpointIfAny());
      }
      return;
    }

    // Listen to Firebase auth changes.
    final authRepo = authRepository;
    if (authRepo != null) {
      _authSubscription = authRepo.authStateChanges().listen((uid) async {
        if (uid != null && uid.isNotEmpty) {
          _isSignedIn = true;
          final profRepo = profileRepository;
          if (profRepo != null) {
            try {
              final prof = await profRepo.getProfile(uid);
              if (prof != null && (prof.uid == uid || prof.uid.isEmpty)) {
                _profile = prof;
              }
            } catch (_) {}
          }
          _subscribeToUserData(uid);
          _subscribeToLeaderboard();
          await _restoreCheckpointIfAny();
        } else {
          _unsubscribeUserData();
          _isSignedIn = false;
        }
        _isAuthBootstrapped = true;
        notifyListeners();
      });
    } else {
      _isAuthBootstrapped = true;
    }

    // Listen to weekly leaderboard query.
    _subscribeToLeaderboard();

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
        if (profile != null && (profile.uid == uid || profile.uid.isEmpty)) {
          _profile = profile;
          if (_lastSyncedReminder != profile.runReminder) {
            _lastSyncedReminder = profile.runReminder;
            unawaited(reminderService?.syncSchedule(profile.runReminder));
          }
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
            (list) async {
              _activities.clear();
              _activities.addAll(list);
              await _mergePendingActivities();
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
        if (_profile.receiveUpdates) {
          push.subscribeToTopic('nearpace_updates');
        } else {
          push.unsubscribeFromTopic('nearpace_updates');
        }
      });
    }
  }

  void _unsubscribeUserData() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _activitiesSubscription?.cancel();
    _activitiesSubscription = null;
  }

  void _subscribeToLeaderboard() {
    final lbRepo = leaderboardRepository;
    if (lbRepo == null) return;

    _leaderboardSubscription?.cancel();
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

  Future<void> refreshLeaderboard() async {
    _subscribeToLeaderboard();
    await Future<void>.delayed(const Duration(milliseconds: 300));
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

  double get longestRunMeters {
    if (_activities.isEmpty) return 0.0;
    var best = 0.0;
    for (final activity in _activities) {
      if (activity.distanceM > best) {
        best = activity.distanceM;
      }
    }
    return best;
  }

  double? get bestPaceSecPerKm {
    double? best;
    for (final activity in _activities) {
      final pace = activity.avgPaceSecPerKm;
      if (pace != null && pace > 0 && !pace.isNaN && !pace.isInfinite) {
        if (best == null || pace < best) {
          best = pace;
        }
      }
    }
    return best;
  }

  Duration get totalDuration =>
      Duration(seconds: _activities.fold(0, (sum, a) => sum + a.durationS));

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
    _lastSyncedReminder = null;
    await reminderService?.cancelAll();
    foregroundService?.stop();
    await checkpointService?.clearCheckpoint();

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
    // Update in-memory leaderboard immediately so it is reflected in UI
    final existingIdx = _leaderboardBase.indexWhere(
      (e) => e.uid == _profile.uid,
    );
    if (existingIdx >= 0) {
      _leaderboardBase[existingIdx] = entry;
    } else {
      _leaderboardBase.add(entry);
    }
    _leaderboardBase.sort((a, b) => b.distanceM.compareTo(a.distanceM));
    notifyListeners();

    try {
      await lbRepo.upsertEntry(entry).timeout(const Duration(seconds: 6));
    } catch (_) {
      // Leaderboard sync failure should not block run save
    }
  }

  // --- Notification Preferences & Run Reminders ---

  Future<void> updateRunReminder(RunReminder reminder) async {
    if (_profile.runReminder == reminder) return;
    _profile = _profile.copyWith(runReminder: reminder);
    _lastSyncedReminder = reminder;
    notifyListeners();

    await reminderService?.syncSchedule(reminder);

    final profRepo = profileRepository;
    if (!_isLocalPreview && profRepo != null && _profile.uid.isNotEmpty) {
      await profRepo.updateNotificationPreferences(
        _profile.uid,
        runReminder: reminder,
      );
    }
  }

  Future<void> setReceiveUpdates(bool enabled) async {
    if (_profile.receiveUpdates == enabled) return;
    _profile = _profile.copyWith(receiveUpdates: enabled);
    notifyListeners();

    final push = pushService;
    if (push != null) {
      if (enabled) {
        await push.subscribeToTopic('nearpace_updates');
      } else {
        await push.unsubscribeFromTopic('nearpace_updates');
      }
    }

    final profRepo = profileRepository;
    if (!_isLocalPreview && profRepo != null && _profile.uid.isNotEmpty) {
      await profRepo.updateNotificationPreferences(
        _profile.uid,
        receiveUpdates: enabled,
      );
    }
  }

  Future<void> sendTestReminder() async {
    final service = reminderService;
    if (_isLocalPreview || service == null) {
      triggerPreviewNotification(
        title: RunReminder.notificationTitle,
        body: RunReminder.testReminderBody,
      );
      return;
    }
    await service.sendTestReminder();
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
    _subscribeToLeaderboard();
  }

  // --- Recording & Permission Flow ---

  void setLocationPermission(LocationPermissionStatus status) {
    _locationPermission = status;
    final loc = locationService;
    if (loc is SimulatedLocationService) {
      loc.setPermission(status);
    }
    if (status == LocationPermissionStatus.denied) {
      _runState = const RunFailed(
        'Location permission was denied. Allow location access while using '
        'NearPace to record GPS distance and pace.',
        reason: RunFailureReason.permissionDenied,
      );
    } else if (status == LocationPermissionStatus.deniedForever) {
      _runState = const RunFailed(
        'Location access is permanently denied. Enable location permission for '
        'NearPace in Android system settings to record runs.',
        reason: RunFailureReason.permissionDeniedForever,
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
    final locService = locationService;
    if (locService != null) {
      final serviceEnabled = await locService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _runState = const RunFailed(
          'Location services are disabled on your device. Enable GPS in settings to record runs.',
          reason: RunFailureReason.serviceDisabled,
        );
        notifyListeners();
        return;
      }

      final permission = await locService.checkPermission();
      if (permission != LocationPermissionStatus.granted &&
          _locationPermission != LocationPermissionStatus.granted) {
        _locationPermission = permission;
        _runState = RunFailed(
          'Location permission is required before starting a run.',
          reason: permission == LocationPermissionStatus.deniedForever
              ? RunFailureReason.permissionDeniedForever
              : RunFailureReason.permissionDenied,
        );
        notifyListeners();
        return;
      }
      _locationPermission = LocationPermissionStatus.granted;
    } else if (_locationPermission != LocationPermissionStatus.granted) {
      _runState = const RunFailed(
        'Location permission is required before starting a run.',
        reason: RunFailureReason.permissionDenied,
      );
      notifyListeners();
      return;
    }

    _cancelRunTimer();
    _positionSubscription?.cancel();
    _runState = const RunPreparing(message: 'Acquiring GPS signal...');
    notifyListeners();

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
        unawaited(preCacheWeatherForecast(points.first));
        _simIndex = 1;
      }

      _runState = const RunActive(paused: false);
      _startRunTimer();
      unawaited(
        foregroundService?.start(
          title: 'NearPace (Running)',
          text: '00:00 • 0.00 km • --:--/km',
          isPaused: false,
        ),
      );
      _saveActiveCheckpoint();
      notifyListeners();
    } else {
      // Warm up GPS hardware with last known position
      try {
        await locService.getLastKnownPosition();
      } catch (_) {}

      final startedAt = DateTime.now();
      final session = RunSession(startedAt: startedAt);
      _activeSession = session;

      var firstFixAcquired = false;
      _positionSubscription = locService.positionStream().listen(
        (point) {
          if (!firstFixAcquired) {
            firstFixAcquired = true;
            unawaited(preCacheWeatherForecast(point));
            if (_runState is RunPreparing) {
              _runState = const RunActive(paused: false);
              _startRunTimer();
              unawaited(
                foregroundService?.start(
                  title: 'NearPace (Running)',
                  text: '00:00 • 0.00 km • --:--/km',
                  isPaused: false,
                ),
              );
              _saveActiveCheckpoint();
              notifyListeners();
            }
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
          _runState = RunFailed('GPS stream error: $error');
          notifyListeners();
        },
      );

      if (acquireDelay > Duration.zero) {
        await Future<void>.delayed(acquireDelay);
      }
      // Gentle status update rather than mapping timeout to failure
      Timer(const Duration(seconds: 10), () {
        if (_runState is RunPreparing && !firstFixAcquired) {
          _runState = const RunPreparing(
            message:
                'Acquiring GPS signal... Moving under open sky speeds this up.',
          );
          notifyListeners();
        }
      });
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
    _updateForegroundNotification();
    _saveActiveCheckpoint();
    notifyListeners();
  }

  void resumeRecording() {
    final session = _activeSession;
    if (session == null || _runState is! RunActive) return;
    session.resume(DateTime.now());
    _runState = const RunActive(paused: false);
    _updateForegroundNotification();
    _saveActiveCheckpoint();
    notifyListeners();
  }

  void resetRecording() {
    _cancelRunTimer();
    _positionSubscription?.cancel();
    _activeSession = null;
    _runState = const RunIdle();
    foregroundService?.stop();
    unawaited(checkpointService?.clearCheckpoint());
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
    foregroundService?.stop();
    unawaited(checkpointService?.clearCheckpoint());
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
      if (_weatherAvailableInPreview && route.isNotEmpty) {
        if (!_isOffline) {
          weather = WeatherSnapshot(
            temperatureC: 27.6,
            apparentC: 29.9,
            code: 1,
            fetchedAt: endedAt,
          );
        } else {
          // Layer 1 Fallback in preview
          weather =
              weatherRepo?.getCachedForecast(route.first, session.startedAt) ??
              WeatherSnapshot(
                temperatureC: 26.5,
                apparentC: 28.0,
                code: 2,
                fetchedAt: session.startedAt,
                isCachedForecast: true,
              );
        }
      }
    } else {
      if (route.isNotEmpty) {
        if (!_isOffline) {
          weather = await weatherRepo.fetchCurrentWeather(route.first);
        }
        // Layer 1 Fallback if live weather is null or device is offline
        weather ??= weatherRepo.getCachedForecast(
          route.first,
          session.startedAt,
        );
      }
    }

    final activity = Activity(
      id: 'run_${endedAt.millisecondsSinceEpoch}',
      startedAt: session.startedAt,
      endedAt: endedAt,
      distanceM: distanceM,
      durationS: elapsed.inSeconds,
      avgPaceSecPerKm: avgPace,
      route: route,
      weather: weather,
      pendingSync: _isOffline,
    );

    _activeSession = null;
    _runState = const RunIdle();
    notifyListeners();
    return activity;
  }

  Future<void> saveActivity(Activity activity) async {
    unawaited(checkpointService?.clearCheckpoint());
    var activityToSave = activity;
    if (_isOffline) {
      activityToSave = activityToSave.copyWith(pendingSync: true);
    }

    final existingIndex = _activities.indexWhere(
      (a) => a.id == activityToSave.id,
    );
    if (existingIndex >= 0) {
      _activities[existingIndex] = activityToSave;
    } else {
      _activities.insert(0, activityToSave);
    }
    notifyListeners();

    final actRepo = activityRepository;
    if (!_isLocalPreview && actRepo != null && _profile.uid.isNotEmpty) {
      _isSavingActivity = true;
      notifyListeners();
      try {
        if (_isOffline) {
          await pendingSyncStorage?.addPendingActivity(activityToSave);
        } else {
          try {
            final savedId = await actRepo.saveActivity(
              _profile.uid,
              activityToSave.copyWith(pendingSync: false),
            );
            final idx = _activities.indexWhere(
              (a) => a.id == activityToSave.id,
            );
            if (idx >= 0) {
              _activities[idx] = activityToSave.copyWith(
                id: savedId,
                pendingSync: false,
              );
            }
            await pendingSyncStorage?.removePendingActivity(activityToSave.id);

            if (activity.isPublic) {
              if (!_profile.showOnLeaderboard) {
                _profile = _profile.copyWith(showOnLeaderboard: true);
                profileRepository?.setShowOnLeaderboard(_profile.uid, true);
              }
              await _syncLeaderboardEntry(runCity: activity.city);
            } else if (_profile.showOnLeaderboard) {
              await _syncLeaderboardEntry();
            }
          } catch (_) {
            final pendingAct = activityToSave.copyWith(pendingSync: true);
            final idx = _activities.indexWhere(
              (a) => a.id == activityToSave.id,
            );
            if (idx >= 0) {
              _activities[idx] = pendingAct;
            }
            await pendingSyncStorage?.addPendingActivity(pendingAct);
          }
        }
      } finally {
        _isSavingActivity = false;
        notifyListeners();
      }
    } else {
      if (activityToSave.pendingSync) {
        await pendingSyncStorage?.addPendingActivity(activityToSave);
      }
    }
  }

  Future<int> syncPendingActivities({bool force = false}) async {
    if (_isSyncingActivities) return 0;

    final conn = connectivityService;
    if (conn != null) {
      _isOffline = !(await conn.checkOnline());
      notifyListeners();
      if (_isOffline && !force) return 0;
    }

    _isSyncingActivities = true;
    notifyListeners();

    var syncedCount = 0;
    try {
      final queue =
          await pendingSyncStorage?.getPendingActivities() ?? const [];
      final pendingInMemory = _activities.where((a) => a.pendingSync).toList();
      final allPending = <String, Activity>{};
      for (final a in queue) {
        allPending[a.id] = a;
      }
      for (final a in pendingInMemory) {
        allPending[a.id] = a;
      }

      if (allPending.isEmpty) return 0;

      final actRepo = activityRepository;
      final weatherRepo = weatherRepository;

      for (final activity in allPending.values) {
        var currentActivity = activity;

        // Layer 2 Weather Backfill if weather is missing or cached forecast
        if ((currentActivity.weather == null ||
                currentActivity.weather!.isCachedForecast) &&
            currentActivity.route.isNotEmpty &&
            weatherRepo != null) {
          final historical = await weatherRepo.fetchHistoricalWeather(
            currentActivity.route.first,
            currentActivity.startedAt,
          );
          if (historical != null) {
            currentActivity = currentActivity.copyWith(weather: historical);
          }
        }

        if (actRepo != null && _profile.uid.isNotEmpty) {
          try {
            final savedId = await actRepo.saveActivity(
              _profile.uid,
              currentActivity.copyWith(pendingSync: false),
            );
            await pendingSyncStorage?.removePendingActivity(activity.id);

            final idx = _activities.indexWhere((a) => a.id == activity.id);
            if (idx >= 0) {
              _activities[idx] = currentActivity.copyWith(
                id: savedId,
                pendingSync: false,
              );
            }
            syncedCount++;
          } catch (_) {
            // Keep pending for next retry
          }
        } else {
          await pendingSyncStorage?.removePendingActivity(activity.id);
          final idx = _activities.indexWhere((a) => a.id == activity.id);
          if (idx >= 0) {
            _activities[idx] = currentActivity.copyWith(pendingSync: false);
          }
          syncedCount++;
        }
      }

      if (syncedCount > 0 && _profile.showOnLeaderboard) {
        await _syncLeaderboardEntry();
      }
    } finally {
      _isSyncingActivities = false;
      notifyListeners();
    }

    return syncedCount;
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
      _tickCount++;
      _updateForegroundNotification();
      if (_tickCount % 5 == 0) {
        _saveActiveCheckpoint();
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
    _tickCount = 0;
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
