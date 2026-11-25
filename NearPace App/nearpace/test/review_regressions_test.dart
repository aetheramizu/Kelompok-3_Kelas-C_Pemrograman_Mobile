import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nearpace/config/firebase_bootstrap.dart';
import 'package:nearpace/data/repositories/activity_repository.dart';
import 'package:nearpace/data/repositories/auth_repository.dart';
import 'package:nearpace/data/repositories/group_repository.dart';
import 'package:nearpace/data/repositories/leaderboard_repository.dart';
import 'package:nearpace/data/repositories/profile_repository.dart';
import 'package:nearpace/data/repositories/weather_repository.dart';
import 'package:nearpace/domain/activity.dart';
import 'package:nearpace/domain/geo_point.dart';
import 'package:nearpace/domain/run_checkpoint.dart';
import 'package:nearpace/domain/run_session.dart';
import 'package:nearpace/domain/run_state.dart';
import 'package:nearpace/domain/user_profile.dart';
import 'package:nearpace/services/connectivity_service.dart';
import 'package:nearpace/services/location_tracking_service.dart';
import 'package:nearpace/services/pending_sync_storage.dart';
import 'package:nearpace/services/run_checkpoint_service.dart';
import 'package:nearpace/services/run_foreground_service.dart';
import 'package:nearpace/services/weather_cache_service.dart';
import 'package:nearpace/state/nearpace_controller.dart';
import 'package:nearpace/theme/nearpace_theme.dart';
import 'package:nearpace/ui/screens/circle_detail_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('Self-review regressions — Open-Meteo UTC & null-slot safety', () {
    test('parseOpenMeteoUtcTime treats zone-less GMT timestamps as UTC without local drift', () {
      final parsed = OpenMeteoWeatherRepository.parseOpenMeteoUtcTime(
        '2026-11-25T02:00',
      );
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      expect(parsed, DateTime.utc(2026, 11, 25, 2, 0));
    });

    test('preCacheHourlyForecast & fetchHistoricalWeather skip null slots and match exact UTC hour', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.queryParameters['timezone'], 'UTC');
        final body = jsonEncode({
          'hourly': {
            'time': [
              '2026-11-25T01:00',
              '2026-11-25T02:00',
              '2026-11-25T03:00',
            ],
            'temperature_2m': [null, 28.4, 29.1],
            'apparent_temperature': [null, 30.2, 31.0],
            'weather_code': [null, 1, 2],
          },
        });
        return http.Response(body, 200);
      });

      final cache = InMemoryWeatherCacheService();
      final repo = OpenMeteoWeatherRepository(
        client: mockHttp,
        cacheService: cache,
      );
      const point = GeoPointLite(latitude: -5.14, longitude: 119.41);

      await repo.preCacheHourlyForecast(point);
      final cached = repo.getCachedForecast(
        point,
        DateTime.utc(2026, 11, 25, 2, 10),
      );
      expect(cached, isNotNull);
      expect(cached!.temperatureC, closeTo(28.4, 0.01));
      expect(cached.isCachedForecast, isTrue);

      final historical = await repo.fetchHistoricalWeather(
        point,
        DateTime.utc(2026, 11, 25, 1, 30),
      );
      // 01:00 slot is null, so it should safely pick the nearest valid slot (02:00).
      expect(historical, isNotNull);
      expect(historical!.temperatureC, closeTo(28.4, 0.01));
      expect(historical.isCachedForecast, isFalse);
    });
  });

  group('Self-review regressions — Offline sync, privacy & UID isolation', () {
    test('InMemoryPendingSyncStorage isolates queued runs per UID when uid is specified', () async {
      final storage = InMemoryPendingSyncStorage();
      final runA = Activity(
        id: 'run_a',
        startedAt: DateTime.utc(2026, 11, 25, 6, 0),
        endedAt: DateTime.utc(2026, 11, 25, 6, 20),
        distanceM: 3200,
        durationS: 1200,
        avgPaceSecPerKm: 375,
        route: const [],
        pendingSync: true,
      );
      final runB = Activity(
        id: 'run_b',
        startedAt: DateTime.utc(2026, 11, 25, 7, 0),
        endedAt: DateTime.utc(2026, 11, 25, 7, 25),
        distanceM: 4100,
        durationS: 1500,
        avgPaceSecPerKm: 365,
        route: const [],
        pendingSync: true,
      );

      await storage.addPendingActivity(runA, uid: 'uid_a');
      await storage.addPendingActivity(runB, uid: 'uid_b');

      final listA = await storage.getPendingActivities(uid: 'uid_a');
      final listB = await storage.getPendingActivities(uid: 'uid_b');

      expect(listA.map((a) => a.id), ['run_a']);
      expect(listB.map((a) => a.id), ['run_b']);
    });

    test('deleting an offline pending run removes it from PendingSyncStorage (no resurrection)', () async {
      final authStream = StreamController<String?>.broadcast();
      addTearDown(authStream.close);

      final syncStorage = InMemoryPendingSyncStorage();
      final connectivity = MockConnectivityService(initialOnline: false);
      final actRepo = MockActivityRepository();
      final controller = NearPaceController(
        firebaseStatus: const FirebaseReady(),
        startSignedIn: true,
        isLocalPreview: false,
        authRepository: MockAuthRepository(
          initialUid: 'runner_del',
          controller: authStream,
        ),
        profileRepository: MockProfileRepository(
          initialProfile: const UserProfile(
            uid: 'runner_del',
            email: 'del@nearpace.id',
            displayName: 'Del Runner',
            city: 'Makassar',
            showOnLeaderboard: false,
          ),
        ),
        activityRepository: actRepo,
        pendingSyncStorage: syncStorage,
        connectivityService: connectivity,
      );
      addTearDown(controller.dispose);
      authStream.add('runner_del');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      controller.setOffline(true);
      final act = Activity(
        id: 'run_delete_me',
        startedAt: DateTime.utc(2026, 11, 25, 6, 0),
        endedAt: DateTime.utc(2026, 11, 25, 6, 15),
        distanceM: 2500,
        durationS: 900,
        avgPaceSecPerKm: 360,
        route: const [],
      );
      await controller.saveActivity(act);
      expect(
        (await syncStorage.getPendingActivities(uid: 'runner_del'))
            .any((a) => a.id == 'run_delete_me'),
        isTrue,
      );

      await controller.deleteActivity('run_delete_me');
      expect(
        (await syncStorage.getPendingActivities(uid: 'runner_del'))
            .any((a) => a.id == 'run_delete_me'),
        isFalse,
      );

      connectivity.setOnline(true);
      controller.setOffline(false);
      final synced = await controller.syncPendingActivities(force: true);
      expect(synced, 0);
      expect(
        controller.activities.any((a) => a.id == 'run_delete_me'),
        isFalse,
      );
    });

    test('private runs (isPublic: false) never leak distance onto public leaderboard, while synced offline public runs opt in & sync city', () async {
      final authStream = StreamController<String?>.broadcast();
      addTearDown(authStream.close);

      final fixedNow = DateTime.utc(2026, 11, 25, 10, 0);
      final syncStorage = InMemoryPendingSyncStorage();
      final connectivity = MockConnectivityService(initialOnline: true);
      final lbRepo = MockLeaderboardRepository();
      final controller = NearPaceController(
        firebaseStatus: const FirebaseReady(),
        clockNow: fixedNow,
        startSignedIn: true,
        isLocalPreview: false,
        authRepository: MockAuthRepository(
          initialUid: 'runner_priv',
          controller: authStream,
        ),
        profileRepository: MockProfileRepository(
          initialProfile: const UserProfile(
            uid: 'runner_priv',
            email: 'priv@nearpace.id',
            displayName: 'Private Runner',
            city: 'Makassar',
            showOnLeaderboard: true,
          ),
        ),
        activityRepository: MockActivityRepository(),
        leaderboardRepository: lbRepo,
        pendingSyncStorage: syncStorage,
        connectivityService: connectivity,
      );
      addTearDown(controller.dispose);
      authStream.add('runner_priv');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Save a private run this week -> public leaderboard distance must remain 0
      await controller.saveActivity(
        Activity(
          id: 'private_run_1',
          startedAt: fixedNow.subtract(const Duration(hours: 2)),
          endedAt: fixedNow.subtract(const Duration(hours: 1, minutes: 30)),
          distanceM: 5000,
          durationS: 1800,
          avgPaceSecPerKm: 360,
          route: const [],
          isPublic: false,
          city: 'Makassar',
        ),
      );
      final entryAfterPrivate = controller.allLeaderboardEntries.firstWhere(
        (e) => e.uid == 'runner_priv',
      );
      expect(entryAfterPrivate.distanceM, 0.0);
      expect(entryAfterPrivate.runCount, 0);

      // Save an offline public run for Bandung, then sync online
      controller.setOffline(true);
      await controller.saveActivity(
        Activity(
          id: 'offline_public_run',
          startedAt: fixedNow.subtract(const Duration(hours: 1)),
          endedAt: fixedNow.subtract(const Duration(minutes: 40)),
          distanceM: 3500,
          durationS: 1200,
          avgPaceSecPerKm: 342.8,
          route: const [],
          isPublic: true,
          city: 'Bandung',
        ),
      );
      controller.setOffline(false);
      await controller.syncPendingActivities(force: true);

      final entryAfterPublicSync = controller.allLeaderboardEntries.firstWhere(
        (e) => e.uid == 'runner_priv',
      );
      expect(entryAfterPublicSync.distanceM, closeTo(3500.0, 0.1));
      expect(entryAfterPublicSync.runCount, 1);
      expect(entryAfterPublicSync.city, 'Bandung');
    });

    test(
      'weeklyAvgPaceSecPerKm returns null instead of 0.0 when duration is 0',
      () async {
        final authStream = StreamController<String?>.broadcast();
        addTearDown(authStream.close);

        final fixedNow = DateTime.utc(2026, 11, 25, 10, 0);
        final controller = NearPaceController(
          firebaseStatus: const FirebaseReady(),
          clockNow: fixedNow,
          startSignedIn: true,
          isLocalPreview: false,
          authRepository: MockAuthRepository(
            initialUid: 'runner_zero',
            controller: authStream,
          ),
          profileRepository: MockProfileRepository(
            initialProfile: const UserProfile(
              uid: 'runner_zero',
              email: 'zero@nearpace.id',
              displayName: 'Zero Dur',
              city: 'Makassar',
              showOnLeaderboard: false,
            ),
          ),
          activityRepository: MockActivityRepository(),
        );
        addTearDown(controller.dispose);
        authStream.add('runner_zero');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        await controller.saveActivity(
          Activity(
            id: 'zero_dur',
            startedAt: fixedNow.subtract(const Duration(minutes: 10)),
            endedAt: fixedNow.subtract(const Duration(minutes: 10)),
            distanceM: 500,
            durationS: 0,
            avgPaceSecPerKm: null,
            route: const [],
          ),
        );
        expect(controller.weeklyAvgPaceSecPerKm, isNull);
      },
    );
  });

  group(
    'Self-review regressions — Checkpoint, Foreground Service & Circles',
    () {
      test('restoring paused checkpoint starts foreground service, resume restarts GPS stream, and stop launches app', () async {
        final authStream = StreamController<String?>.broadcast();
        addTearDown(authStream.close);

        final fg = NoopRunForegroundService();
        final simLocation = SimulatedLocationService(
          initialPermission: LocationPermissionStatus.granted,
        );
        final chkService = InMemoryRunCheckpointService();
        final now = DateTime.now();
        await chkService.saveCheckpoint(
          RunCheckpoint(
            startedAt: now.subtract(const Duration(minutes: 10)),
            pausedTotalMs: 0,
            pausedAt: now.subtract(const Duration(minutes: 1)),
            isPaused: true,
            distanceM: 0,
            lastSavedAt: now.subtract(const Duration(seconds: 30)),
            samples: [
              RunSample(
                point: GeoPointLite(
                  latitude: -5.1400,
                  longitude: 119.4100,
                  accuracyM: 6,
                  recordedAt: now.subtract(const Duration(minutes: 2)),
                ),
                at: now.subtract(const Duration(minutes: 2)),
              ),
            ],
          ),
        );

        final controller = NearPaceController(
          firebaseStatus: const FirebaseReady(),
          startSignedIn: true,
          isLocalPreview: false,
          authRepository: MockAuthRepository(
            initialUid: 'runner_chk',
            controller: authStream,
          ),
          profileRepository: MockProfileRepository(
            initialProfile: const UserProfile(
              uid: 'runner_chk',
              email: 'chk@nearpace.id',
              displayName: 'Checkpoint Runner',
              city: 'Makassar',
              showOnLeaderboard: false,
            ),
          ),
          locationService: simLocation,
          foregroundService: fg,
          checkpointService: chkService,
        );
        addTearDown(controller.dispose);
        authStream.add('runner_chk');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(controller.runState, isA<RunActive>());
        expect((controller.runState as RunActive).paused, isTrue);
        expect(fg.startCount, greaterThanOrEqualTo(1));

        // Resume should re-attach GPS stream so new samples are recorded
        controller.resumeRecording();
        expect((controller.runState as RunActive).paused, isFalse);

        final beforeSamples = controller.activeSession!.samples.length;
        simLocation.emitPoint(
          GeoPointLite(
            latitude: -5.1405,
            longitude: 119.4105,
            accuracyM: 5,
            recordedAt: DateTime.now(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          controller.activeSession!.samples.length,
          greaterThan(beforeSamples),
        );

        // Notification 'stop' action pauses & launches app
        fg.simulateAction('stop');
        expect((controller.runState as RunActive).paused, isTrue);
        expect(fg.launchAppCount, 1);
      });

      test('restoring stale unpaused checkpoint (>2 min old) auto-pauses to avoid inflating elapsed time', () async {
        final chkService = InMemoryRunCheckpointService();
        final now = DateTime.now();
        final lastSaved = now.subtract(const Duration(minutes: 30));
        await chkService.saveCheckpoint(
          RunCheckpoint(
            startedAt: lastSaved.subtract(const Duration(minutes: 5)),
            pausedTotalMs: 0,
            pausedAt: null,
            isPaused: false,
            distanceM: 0,
            lastSavedAt: lastSaved,
            samples: const [],
          ),
        );

        final controller = NearPaceController(
          firebaseStatus: const FirebaseReady(),
          startSignedIn: true,
          isLocalPreview: true,
          foregroundService: NoopRunForegroundService(),
          checkpointService: chkService,
        );
        addTearDown(controller.dispose);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(controller.runState, isA<RunActive>());
        expect((controller.runState as RunActive).paused, isTrue);
        final elapsed = controller.activeSession!.elapsedAt(DateTime.now());
        // Should be ~5 minutes, NOT ~35 minutes!
        expect(elapsed.inMinutes, lessThan(10));
      });

      testWidgets(
        'CircleDetailScreen shows Circle unavailable when circle is removed remotely',
        (tester) async {
          final groupRepo = MockGroupRepository();
          final controller = NearPaceController(
            firebaseStatus: const FirebaseUnconfigured({}),
            startSignedIn: true,
            isLocalPreview: true,
            groupRepository: groupRepo,
          );
          addTearDown(controller.dispose);

          final created = await controller.createGroup(name: 'Ephemeral Crew');
          await tester.pumpWidget(
            ChangeNotifierProvider<NearPaceController>.value(
              value: controller,
              child: MaterialApp(
                theme: NearPaceTheme.dark(),
                home: CircleDetailScreen(
                  groupId: created.id,
                  initialGroup: created,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Ephemeral Crew'), findsAtLeastNWidgets(1));

          // Simulate circle disappearing remotely
          await groupRepo.deleteGroup(
            groupId: created.id,
            ownerUid: controller.profile.uid,
          );
          await tester.pumpAndSettle();

          expect(find.text('Circle unavailable'), findsOneWidget);
        },
      );
    },
  );
}
