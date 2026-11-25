import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearpace/data/repositories/auth_repository.dart';
import 'package:nearpace/data/repositories/profile_repository.dart';
import 'package:nearpace/domain/geo_point.dart';
import 'package:nearpace/domain/run_checkpoint.dart';
import 'package:nearpace/domain/run_session.dart';
import 'package:nearpace/domain/run_state.dart';
import 'package:nearpace/domain/user_profile.dart';
import 'package:nearpace/main.dart';
import 'package:nearpace/services/location_tracking_service.dart';
import 'package:nearpace/services/run_checkpoint_service.dart';
import 'package:nearpace/services/run_foreground_service.dart';
import 'package:nearpace/state/nearpace_controller.dart';
import 'package:nearpace/ui/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 - Auth Bootstrap Gate & Splash Screen', () {
    testWidgets('shows SplashScreen until auth bootstrap completes', (
      tester,
    ) async {
      final authStreamController = StreamController<String?>.broadcast();
      final mockAuth = MockAuthRepository(controller: authStreamController);

      final controller = NearPaceController(
        firebaseStatus: const FirebaseReady(),
        isLocalPreview: false,
        isAuthBootstrapped: false,
        authRepository: mockAuth,
      );

      await tester.pumpWidget(
        NearPaceApp(
          firebaseStatus: const FirebaseReady(),
          isAuthBootstrapped: false,
          authRepository: mockAuth,
        ),
      );

      // Initially on Splash screen
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('NearPace'), findsOneWidget);
      expect(find.text('Hyperlocal running companion'), findsOneWidget);

      controller.dispose();
      authStreamController.close();
    });

    test('NearPaceController bootstraps and restores profile before revealing session', () async {
      final authController = StreamController<String?>.broadcast();
      final mockAuth = MockAuthRepository(controller: authController);
      final mockProfile = MockProfileRepository(
        initialProfile: const UserProfile(
          uid: 'user-123',
          email: 'test@nearpace.id',
          displayName: 'Test Runner',
          city: 'Jakarta',
          showOnLeaderboard: true,
        ),
      );

      final controller = NearPaceController(
        firebaseStatus: const FirebaseReady(),
        isLocalPreview: false,
        isAuthBootstrapped: false,
        authRepository: mockAuth,
        profileRepository: mockProfile,
      );

      expect(controller.isAuthBootstrapped, isFalse);

      // Emit signed-in user
      authController.add('user-123');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.isSignedIn, isTrue);
      expect(controller.isAuthBootstrapped, isTrue);

      controller.dispose();
      authController.close();
    });
  });

  group('Phase 1 - GPS Permission & State Separation', () {
    test(
      'remembers granted location permission and does not false-block on delay',
      () async {
        final simLocation = SimulatedLocationService(
          initialPermission: LocationPermissionStatus.granted,
          serviceEnabled: true,
        );

        final controller = NearPaceController(
          firebaseStatus: const FirebaseReady(),
          isLocalPreview: false,
          isAuthBootstrapped: true,
          startSignedIn: true,
          locationService: simLocation,
          foregroundService: NoopRunForegroundService(),
          checkpointService: InMemoryRunCheckpointService(),
        );

        final status = await controller.checkLocationPermission();
        expect(status, LocationPermissionStatus.granted);
        expect(controller.locationPermission, LocationPermissionStatus.granted);

        // Starting recording should transition to RunPreparing without throwing GPS blocked
        await controller.startRecording(acquireDelay: Duration.zero);
        expect(controller.runState, isA<RunPreparing>());

        // Emit GPS point -> smoothly transitions to RunActive
        simLocation.emitPoint(
          GeoPointLite(
            latitude: -6.2,
            longitude: 106.8,
            accuracyM: 5.0,
            recordedAt: DateTime.now(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(controller.runState, isA<RunActive>());
        expect((controller.runState as RunActive).paused, isFalse);

        controller.dispose();
      },
    );

    test('accurately identifies disabled location services and maps to serviceDisabled', () async {
      final simLocation = SimulatedLocationService(
        initialPermission: LocationPermissionStatus.granted,
        serviceEnabled: false,
      );

      final controller = NearPaceController(
        firebaseStatus: const FirebaseReady(),
        isLocalPreview: false,
        isAuthBootstrapped: true,
        startSignedIn: true,
        locationService: simLocation,
        foregroundService: NoopRunForegroundService(),
        checkpointService: InMemoryRunCheckpointService(),
      );

      await controller.startRecording(acquireDelay: Duration.zero);
      expect(controller.runState, isA<RunFailed>());
      final failed = controller.runState as RunFailed;
      expect(failed.reason, RunFailureReason.serviceDisabled);

      controller.dispose();
    });

    test('accurately identifies denied location permission and maps to permissionDenied', () async {
      final simLocation = SimulatedLocationService(
        initialPermission: LocationPermissionStatus.denied,
        serviceEnabled: true,
      );

      final controller = NearPaceController(
        firebaseStatus: const FirebaseReady(),
        isLocalPreview: false,
        isAuthBootstrapped: true,
        startSignedIn: true,
        locationService: simLocation,
        foregroundService: NoopRunForegroundService(),
        checkpointService: InMemoryRunCheckpointService(),
      );

      await controller.startRecording(acquireDelay: Duration.zero);
      expect(controller.runState, isA<RunFailed>());
      final failed = controller.runState as RunFailed;
      expect(failed.reason, RunFailureReason.permissionDenied);

      controller.dispose();
    });
  });

  group('Phase 1 - Foreground Service & Crash-Safe Checkpoint Survival', () {
    test('manages foreground service notifications and handles sticky notification actions', () async {
      final mockForeground = NoopRunForegroundService();
      final mockCheckpoint = InMemoryRunCheckpointService();
      final simLocation = SimulatedLocationService(
        initialPermission: LocationPermissionStatus.granted,
      );

      final controller = NearPaceController(
        firebaseStatus: const FirebaseReady(),
        isLocalPreview: true,
        isAuthBootstrapped: true,
        startSignedIn: true,
        locationService: simLocation,
        foregroundService: mockForeground,
        checkpointService: mockCheckpoint,
      );

      await controller.startRecording(acquireDelay: Duration.zero);
      expect(controller.runState, isA<RunActive>());
      expect((controller.runState as RunActive).paused, isFalse);

      // Checkpoint was saved on start
      var checkpoint = await mockCheckpoint.loadCheckpoint();
      expect(checkpoint, isNotNull);
      expect(checkpoint!.isPaused, isFalse);

      // Notification action button 'pause'
      mockForeground.simulateAction('pause');
      expect(controller.runState, isA<RunActive>());
      expect((controller.runState as RunActive).paused, isTrue);

      checkpoint = await mockCheckpoint.loadCheckpoint();
      expect(checkpoint!.isPaused, isTrue);

      // Notification action button 'continue'
      mockForeground.simulateAction('continue');
      expect(controller.runState, isA<RunActive>());
      expect((controller.runState as RunActive).paused, isFalse);

      controller.resetRecording();
      expect(await mockCheckpoint.loadCheckpoint(), isNull);

      controller.dispose();
    });

    test('recovers in-flight run session from checkpoint seamlessly after process kill', () async {
      final mockCheckpoint = InMemoryRunCheckpointService();
      final now = DateTime.now();

      final savedSession = RunSession(
        startedAt: now.subtract(const Duration(minutes: 10)),
      );
      savedSession.addSample(
        GeoPointLite(
          latitude: -6.200,
          longitude: 106.800,
          accuracyM: 5.0,
          recordedAt: now.subtract(const Duration(minutes: 9)),
        ),
        now.subtract(const Duration(minutes: 9)),
      );
      savedSession.addSample(
        GeoPointLite(
          latitude: -6.205,
          longitude: 106.805,
          accuracyM: 5.0,
          recordedAt: now.subtract(const Duration(minutes: 5)),
        ),
        now.subtract(const Duration(minutes: 5)),
      );

      // Save active checkpoint
      await mockCheckpoint.saveCheckpoint(
        RunCheckpoint.fromSession(
          savedSession,
          isPaused: false,
          lastSavedAt: now,
        ),
      );

      // Spin up fresh controller as if after app process restart
      final controller = NearPaceController(
        firebaseStatus: const FirebaseReady(),
        isLocalPreview: true,
        isAuthBootstrapped: true,
        startSignedIn: true,
        foregroundService: NoopRunForegroundService(),
        checkpointService: mockCheckpoint,
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Active session must be restored automatically without losing progress!
      expect(controller.runState, isA<RunActive>());
      expect(controller.activeSession, isNotNull);
      expect(controller.activeSession!.samples.length, 2);
      expect(controller.activeSession!.distanceMeters, greaterThan(500));

      controller.dispose();
    });
  });
}
