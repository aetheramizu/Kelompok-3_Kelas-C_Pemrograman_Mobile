import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'config/firebase_bootstrap.dart';
import 'config/firebase_config.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/leaderboard_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/weather_repository.dart';
import 'services/connectivity_service.dart';
import 'services/location_tracking_service.dart';
import 'services/pending_sync_storage.dart';
import 'services/push_notification_service.dart';
import 'services/run_checkpoint_service.dart';
import 'services/run_foreground_service.dart';
import 'services/run_reminder_service.dart';
import 'services/weather_cache_service.dart';
import 'state/nearpace_controller.dart';
import 'theme/nearpace_spacing.dart';
import 'theme/nearpace_theme.dart';
import 'ui/screens/app_shell.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/splash_screen.dart';

/// Root NearPace Flutter application wiring theme, state controller, and the
/// authentication gate.
class NearPaceApp extends StatelessWidget {
  NearPaceApp({
    super.key,
    FirebaseBootstrapStatus? firebaseStatus,
    this.startSignedIn = false,
    this.isAuthBootstrapped,
    this.clockNow,
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
  }) : firebaseStatus =
           firebaseStatus ?? FirebaseUnconfigured(FirebaseConfig.missingKeys);

  final FirebaseBootstrapStatus firebaseStatus;
  final bool startSignedIn;
  final bool? isAuthBootstrapped;
  final DateTime? clockNow;

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

  @override
  Widget build(BuildContext context) {
    final hasFirebase = Firebase.apps.isNotEmpty;
    final isReady = firebaseStatus is FirebaseReady && hasFirebase;
    final weatherCache =
        weatherCacheService ??
        (isReady
            ? PreferencesWeatherCacheService()
            : InMemoryWeatherCacheService());

    return ChangeNotifierProvider<NearPaceController>(
      create: (_) => NearPaceController(
        firebaseStatus: firebaseStatus,
        startSignedIn: startSignedIn,
        isAuthBootstrapped: isAuthBootstrapped,
        clockNow: clockNow,
        isLocalPreview: !isReady,
        authRepository:
            authRepository ??
            (isReady ? FirebaseAuthRepository() : MockAuthRepository()),
        profileRepository:
            profileRepository ??
            (isReady ? FirestoreProfileRepository() : MockProfileRepository()),
        activityRepository:
            activityRepository ??
            (isReady
                ? FirestoreActivityRepository()
                : MockActivityRepository()),
        leaderboardRepository:
            leaderboardRepository ??
            (isReady
                ? FirestoreLeaderboardRepository()
                : MockLeaderboardRepository()),
        weatherRepository:
            weatherRepository ??
            (isReady
                ? OpenMeteoWeatherRepository(cacheService: weatherCache)
                : MockWeatherRepository()),
        locationService:
            locationService ??
            (isReady
                ? const GeolocatorTrackingService()
                : SimulatedLocationService()),
        pushService:
            pushService ??
            (isReady
                ? FcmPushNotificationService()
                : NoopPushNotificationService()),
        reminderService:
            reminderService ??
            (isReady ? LocalRunReminderService() : NoopRunReminderService()),
        foregroundService:
            foregroundService ??
            (isReady
                ? FlutterForegroundRunService()
                : NoopRunForegroundService()),
        checkpointService:
            checkpointService ??
            (isReady
                ? PreferencesRunCheckpointService()
                : InMemoryRunCheckpointService()),
        pendingSyncStorage:
            pendingSyncStorage ??
            (isReady
                ? PreferencesPendingSyncStorage()
                : InMemoryPendingSyncStorage()),
        weatherCacheService: weatherCache,
        connectivityService:
            connectivityService ??
            (isReady ? SystemConnectivityService() : MockConnectivityService()),
      ),
      child: const _NearPaceMaterialApp(),
    );
  }
}

class _NearPaceMaterialApp extends StatefulWidget {
  const _NearPaceMaterialApp();

  @override
  State<_NearPaceMaterialApp> createState() => _NearPaceMaterialAppState();
}

class _NearPaceMaterialAppState extends State<_NearPaceMaterialApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = context.read<NearPaceController>();
    controller.handleAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      controller.syncCoordinator?.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();

    return MaterialApp(
      title: 'NearPace',
      debugShowCheckedModeBanner: false,
      theme: NearPaceTheme.light(),
      darkTheme: NearPaceTheme.dark(),
      themeMode: controller.themeMode,
      home: AnimatedSwitcher(
        duration: NearPaceMotion.resolve(context, NearPaceMotion.standard),
        switchInCurve: NearPaceMotion.easeOut,
        child: !controller.isAuthBootstrapped
            ? const SplashScreen(key: ValueKey('splash-screen'))
            : (controller.isSignedIn
                  ? const AppShell(key: ValueKey('app-shell'))
                  : const AuthScreen(key: ValueKey('auth-screen'))),
      ),
    );
  }
}
