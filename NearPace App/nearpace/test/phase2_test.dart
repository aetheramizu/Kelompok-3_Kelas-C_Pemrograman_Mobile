import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nearpace/config/firebase_bootstrap.dart';
import 'package:nearpace/data/repositories/activity_repository.dart';
import 'package:nearpace/data/repositories/auth_repository.dart';
import 'package:nearpace/data/repositories/leaderboard_repository.dart';
import 'package:nearpace/data/repositories/profile_repository.dart';
import 'package:nearpace/data/repositories/weather_repository.dart';
import 'package:nearpace/domain/activity.dart';
import 'package:nearpace/domain/geo_point.dart';
import 'package:nearpace/domain/user_profile.dart';
import 'package:nearpace/domain/weather.dart';
import 'package:nearpace/services/connectivity_service.dart';
import 'package:nearpace/services/pending_sync_storage.dart';
import 'package:nearpace/services/weather_cache_service.dart';
import 'package:nearpace/state/nearpace_controller.dart';
import 'package:nearpace/theme/nearpace_theme.dart';
import 'package:nearpace/ui/widgets/activity_card.dart';
import 'package:nearpace/ui/widgets/weather_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 - Offline Sync Storage & Idempotency', () {
    test(
      'InMemoryPendingSyncStorage stores and removes activities idempotently',
      () async {
        final storage = InMemoryPendingSyncStorage();
        final act1 = Activity(
          id: 'run_1001',
          startedAt: DateTime.utc(2026, 11, 24, 6, 0),
          endedAt: DateTime.utc(2026, 11, 24, 6, 30),
          distanceM: 5000,
          durationS: 1800,
          avgPaceSecPerKm: 360.0,
          route: const [],
          pendingSync: true,
        );

        await storage.addPendingActivity(act1);
        var pending = await storage.getPendingActivities();
        expect(pending.length, 1);
        expect(pending.first.id, 'run_1001');

        // Adding duplicate ID updates rather than creates duplicate
        final act1Updated = act1.copyWith(distanceM: 5200);
        await storage.addPendingActivity(act1Updated);
        pending = await storage.getPendingActivities();
        expect(pending.length, 1);
        expect(pending.first.distanceM, 5200);

        // Remove activity
        await storage.removePendingActivity('run_1001');
        pending = await storage.getPendingActivities();
        expect(pending.isEmpty, isTrue);
      },
    );
  });

  group('Phase 2 - 2-Layer Weather System (Pre-Cache & Backfill)', () {
    test(
      'WeatherCacheService saves hourly forecast and retrieves matching time',
      () async {
        final cache = InMemoryWeatherCacheService();
        final baseTime = DateTime.utc(2026, 11, 24, 6, 0);

        await cache.saveHourlyForecast(
          latitude: -6.2088,
          longitude: 106.8456,
          times: [
            baseTime,
            baseTime.add(const Duration(hours: 1)),
            baseTime.add(const Duration(hours: 2)),
          ],
          temperatures: [26.0, 27.5, 29.0],
          apparentTemperatures: [28.0, 30.0, 32.0],
          weatherCodes: [1, 2, 3],
        );

        // Closest to baseTime + 45 min should pick baseTime + 1 hr (27.5°C)
        final match = cache.getCachedForecastForTime(
          latitude: -6.2088,
          longitude: 106.8456,
          targetTime: baseTime.add(const Duration(minutes: 45)),
        );

        expect(match, isNotNull);
        expect(match!.temperatureC, 27.5);
        expect(match.isCachedForecast, isTrue);
        expect(match.code, 2);

        // Location too far (> 0.5 degree) returns null
        final farLocationMatch = cache.getCachedForecastForTime(
          latitude: -7.5,
          longitude: 106.8456,
          targetTime: baseTime,
        );
        expect(farLocationMatch, isNull);
      },
    );

    test('MockWeatherRepository provides Layer 1 pre-cache & Layer 2 historical backfill', () async {
      final repo = MockWeatherRepository(
        cachedSnapshot: WeatherSnapshot(
          temperatureC: 25.5,
          apparentC: 27.0,
          code: 1,
          fetchedAt: DateTime(2026, 11, 24, 6, 0),
          isCachedForecast: true,
        ),
        historicalSnapshot: WeatherSnapshot(
          temperatureC: 26.0,
          apparentC: 28.0,
          code: 0,
          fetchedAt: DateTime(2026, 11, 24, 6, 0),
          isCachedForecast: false,
        ),
      );

      final point = const GeoPointLite(latitude: -6.2, longitude: 106.8);
      final runTime = DateTime.utc(2026, 11, 24, 6, 0);

      // Layer 1
      final cached = repo.getCachedForecast(point, runTime);
      expect(cached, isNotNull);
      expect(cached!.isCachedForecast, isTrue);
      expect(cached.temperatureC, 25.5);

      // Layer 2
      final historical = await repo.fetchHistoricalWeather(point, runTime);
      expect(historical, isNotNull);
      expect(historical!.isCachedForecast, isFalse);
      expect(historical.temperatureC, 26.0);
      expect(repo.historicalCalled, isTrue);
    });
  });

  group('Phase 2 - Offline Sync Coordinator & Controller Flow', () {
    late MockConnectivityService connectivity;
    late InMemoryPendingSyncStorage syncStorage;
    late MockActivityRepository actRepo;
    late MockWeatherRepository weatherRepo;
    late NearPaceController controller;

    setUp(() {
      connectivity = MockConnectivityService(initialOnline: true);
      syncStorage = InMemoryPendingSyncStorage();
      actRepo = MockActivityRepository();
      weatherRepo = MockWeatherRepository();

      controller = NearPaceController(
        firebaseStatus: const FirebaseReady(),
        startSignedIn: true,
        isLocalPreview: false,
        authRepository: MockAuthRepository(initialUid: 'runner_123'),
        profileRepository: MockProfileRepository(
          initialProfile: const UserProfile(
            uid: 'runner_123',
            email: 'runner@nearpace.id',
            displayName: 'Indra Runner',
            city: 'Jakarta',
            showOnLeaderboard: true,
          ),
        ),
        activityRepository: actRepo,
        leaderboardRepository: MockLeaderboardRepository(),
        weatherRepository: weatherRepo,
        pendingSyncStorage: syncStorage,
        connectivityService: connectivity,
      );
    });

    test(
      'Saves activity offline as pendingSync and queues in storage',
      () async {
        // Simulate going offline
        controller.setOffline(true);
        expect(controller.isOffline, isTrue);

        final act = Activity(
          id: 'run_offline_1',
          startedAt: DateTime.utc(2026, 11, 24, 5, 30),
          endedAt: DateTime.utc(2026, 11, 24, 6, 0),
          distanceM: 4200,
          durationS: 1500,
          avgPaceSecPerKm: 357.0,
          route: const [GeoPointLite(latitude: -6.2, longitude: 106.8)],
        );

        await controller.saveActivity(act);

        // Activity should appear in activities list with pendingSync = true
        final saved = controller.activities.firstWhere(
          (a) => a.id == 'run_offline_1',
        );
        expect(saved.pendingSync, isTrue);
        expect(controller.pendingSyncCount, greaterThanOrEqualTo(1));

        // Persisted in sync queue
        final queued = await syncStorage.getPendingActivities();
        expect(queued.any((a) => a.id == 'run_offline_1'), isTrue);
      },
    );

    test(
      'Backfills weather and syncs pending activities when back online',
      () async {
        controller.setOffline(true);
        final act = Activity(
          id: 'run_offline_2',
          startedAt: DateTime.utc(2026, 11, 24, 5, 0),
          endedAt: DateTime.utc(2026, 11, 24, 5, 30),
          distanceM: 3000,
          durationS: 1200,
          avgPaceSecPerKm: 400.0,
          route: const [GeoPointLite(latitude: -6.2, longitude: 106.8)],
          weather: null, // missing weather
        );
        await controller.saveActivity(act);
        expect(controller.pendingSyncCount, greaterThanOrEqualTo(1));

        // Come back online
        controller.setOffline(false);
        connectivity.setOnline(true);

        final syncedCount = await controller.syncPendingActivities(force: true);
        expect(syncedCount, greaterThanOrEqualTo(1));

        // Synced activity should now have pendingSync = false and backfilled weather
        final synced = controller.activities.firstWhere(
          (a) => a.id == 'run_offline_2',
        );
        expect(synced.pendingSync, isFalse);
        expect(synced.weather, isNotNull);
        expect(synced.weather!.isCachedForecast, isFalse);

        // Removed from queue
        final queued = await syncStorage.getPendingActivities();
        expect(queued.any((a) => a.id == 'run_offline_2'), isFalse);
      },
    );
  });

  group('Phase 2 - UI Widgets for Pending Sync & Cached Weather', () {
    testWidgets(
      'ActivityCard renders Pending sync badge when activity.pendingSync is true',
      (tester) async {
        final act = Activity(
          id: 'test_run',
          startedAt: DateTime.utc(2026, 11, 24, 6, 0),
          endedAt: DateTime.utc(2026, 11, 24, 6, 30),
          distanceM: 5000,
          durationS: 1800,
          avgPaceSecPerKm: 360.0,
          route: const [],
          pendingSync: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: NearPaceTheme.dark(),
            home: Scaffold(
              body: ActivityCard(activity: act, onTap: () {}),
            ),
          ),
        );

        expect(find.text('Pending sync'), findsOneWidget);
      },
    );

    testWidgets(
      'WeatherSummaryCard renders Cached forecast pill and Layer 1 note',
      (tester) async {
        final weather = WeatherSnapshot(
          temperatureC: 26.0,
          apparentC: 28.0,
          code: 1,
          fetchedAt: DateTime(2026, 11, 24, 6, 0),
          isCachedForecast: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: NearPaceTheme.dark(),
            home: Scaffold(body: WeatherSummaryCard(weather: weather)),
          ),
        );

        expect(find.text('Cached forecast'), findsOneWidget);
        expect(find.text('Layer 1 Offline Cache'), findsOneWidget);
      },
    );
  });
}
