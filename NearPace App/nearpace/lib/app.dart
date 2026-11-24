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
import 'services/location_tracking_service.dart';
import 'services/push_notification_service.dart';
import 'services/run_checkpoint_service.dart';
import 'services/run_foreground_service.dart';
import 'services/run_reminder_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final hasFirebase = Firebase.apps.isNotEmpty;
    final isReady = firebaseStatus is FirebaseReady && hasFirebase;

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
            (isReady ? OpenMeteoWeatherRepository() : MockWeatherRepository()),
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
    context.read<NearPaceController>().handleAppLifecycleState(state);
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
