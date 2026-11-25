import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nearpace/app.dart';
import 'package:nearpace/domain/activity.dart';
import 'package:nearpace/domain/geo_point.dart';
import 'package:nearpace/domain/leaderboard_entry.dart';
import 'package:nearpace/domain/user_profile.dart';
import 'package:nearpace/services/indonesian_cities.dart';
import 'package:nearpace/services/location_tracking_service.dart';
import 'package:nearpace/theme/nearpace_theme.dart';
import 'package:nearpace/ui/widgets/avatar_picker_sheet.dart';
import 'package:nearpace/ui/widgets/city_picker_sheet.dart';
import 'package:nearpace/ui/widgets/nearpace_avatar.dart';
import 'package:nearpace/ui/widgets/route_sketch.dart';
import 'package:nearpace/ui/widgets/share_activity_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Indonesian Cities & Haversine
  // ---------------------------------------------------------------------------

  group('Phase 3 - Indonesian Cities Service', () {
    test('fallbackCities is non-empty and contains Jakarta Pusat', () {
      final cities = IndonesianCitiesService.fallbackCities;
      expect(cities, isNotEmpty);
      expect(cities.any((c) => c.name == 'Jakarta Pusat'), isTrue);
    });

    test(
      'bundled indonesia_cities.json covers all 38 provinces cleanly',
      () async {
        final cities = await IndonesianCitiesService.loadCities();
        expect(cities.length, greaterThanOrEqualTo(200));

        final provinces = cities.map((c) => c.province).toSet();
        expect(provinces.length, 38);

        final names = cities.map((c) => c.name).toSet();
        expect(
          names.length,
          cities.length,
          reason: 'City names must be unique',
        );
      },
    );

    test('Haversine distance between Jakarta and Surabaya ≈ 660-680 km', () {
      // Jakarta Pusat → Surabaya
      final dist = IndonesianCitiesService.haversineDistanceKm(
        -6.186486,
        106.834091,
        -7.257472,
        112.752088,
      );
      expect(dist, greaterThan(640));
      expect(dist, lessThan(700));
    });

    test('findNearestCity picks Makassar for coordinate near Makassar', () {
      // A point close to Makassar centroid
      final nearest = IndonesianCitiesService.findNearestCity(
        -5.15,
        119.43,
        customCities: IndonesianCitiesService.fallbackCities,
      );
      expect(nearest.name, 'Makassar');
    });

    test('findNearestCity picks Denpasar for coordinate near Bali', () {
      final nearest = IndonesianCitiesService.findNearestCity(
        -8.65,
        115.22,
        customCities: IndonesianCitiesService.fallbackCities,
      );
      expect(nearest.name, 'Denpasar');
    });

    test('searchCities filters by name and province substring', () {
      final results = IndonesianCitiesService.searchCities(
        'jakarta',
        customCities: IndonesianCitiesService.fallbackCities,
      );
      // Should match all 5 Jakarta variants + possibly DKI Jakarta provinces
      expect(results.length, greaterThanOrEqualTo(5));

      final provinceResult = IndonesianCitiesService.searchCities(
        'bali',
        customCities: IndonesianCitiesService.fallbackCities,
      );
      expect(provinceResult.any((c) => c.name == 'Denpasar'), isTrue);
    });

    test('searchCities returns all when query is empty', () {
      final results = IndonesianCitiesService.searchCities(
        '',
        customCities: IndonesianCitiesService.fallbackCities,
      );
      expect(results.length, IndonesianCitiesService.fallbackCities.length);
    });
  });

  // ---------------------------------------------------------------------------
  // CityPickerSheet & Leaderboard City Filter Pill
  // ---------------------------------------------------------------------------

  group('Phase 3 - CityPickerSheet & Leaderboard City Filter', () {
    testWidgets('CityPickerSheet supports live search and Detect from GPS', (
      tester,
    ) async {
      String? picked;
      final locationService = SimulatedLocationService();

      await tester.pumpWidget(
        NearPaceApp(
          startSignedIn: true,
          locationService: locationService,
          clockNow: DateTime(2026, 11, 24, 9, 0),
        ),
      );
      await tester.pumpAndSettle();

      // Open CityPickerSheet from a BuildContext that has NearPaceController
      final context = tester.element(find.text('Home'));
      final future = CityPickerSheet.show(context, currentCity: 'Makassar');
      await tester.pumpAndSettle();

      expect(find.text('Detect from GPS'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Surabaya');
      await tester.pumpAndSettle();
      expect(find.text('Surabaya'), findsWidgets);

      await tester.tap(find.widgetWithText(ListTile, 'Surabaya'));
      await tester.pumpAndSettle();
      picked = await future;
      expect(picked, 'Surabaya');
    });

    testWidgets(
      'LeaderboardScreen opens searchable city filter sheet from pill',
      (tester) async {
        await tester.pumpWidget(
          NearPaceApp(
            startSignedIn: true,
            clockNow: DateTime(2026, 11, 24, 9, 0),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ranks'));
        await tester.pumpAndSettle();

        expect(find.textContaining('All Indonesia'), findsOneWidget);
        await tester.tap(find.textContaining('All Indonesia'));
        await tester.pumpAndSettle();

        expect(find.text('Filter by City'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Bandung');
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ListTile, 'Bandung'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Bandung ('), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Avatar Presets & Domain Model
  // ---------------------------------------------------------------------------

  group('Phase 3 - NearPace Avatars & Domain Models', () {
    test('kNearPaceAvatars has exactly 12 unique characters', () {
      expect(kNearPaceAvatars.length, 12);
      final ids = kNearPaceAvatars.map((a) => a.id).toSet();
      expect(ids.length, 12, reason: 'Each avatar must have a unique ID');
    });

    test('avatars span 8 runners and 4 mascots', () {
      final runners = kNearPaceAvatars
          .where((a) => a.category == 'runners')
          .length;
      final mascots = kNearPaceAvatars
          .where((a) => a.category == 'mascots')
          .length;
      expect(runners, 8);
      expect(mascots, 4);
    });

    test('UserProfile carries avatarId through copyWith and toMap/fromMap', () {
      const profile = UserProfile(
        uid: 'u1',
        email: 'runner@test.com',
        displayName: 'Test Runner',
        city: 'Makassar',
        showOnLeaderboard: true,
        avatarId: 'volt_sprinter',
      );

      expect(profile.avatarId, 'volt_sprinter');

      final copied = profile.copyWith(avatarId: 'trail_explorer');
      expect(copied.avatarId, 'trail_explorer');
      expect(copied.displayName, 'Test Runner');

      final map = profile.toMap();
      expect(map['avatarId'], 'volt_sprinter');

      final restored = UserProfile.fromMap('u1', map);
      expect(restored.avatarId, 'volt_sprinter');
      expect(restored.uid, 'u1');
    });

    test('LeaderboardEntry carries avatarId through copyWith and fromMap', () {
      final entry = LeaderboardEntry(
        uid: 'u1',
        displayName: 'Runner A',
        city: 'Bandung',
        weekKey: '2026-11-23',
        distanceM: 10000,
        runCount: 3,
        updatedAt: DateTime.utc(2026, 11, 24),
        avatarId: 'night_runner',
      );

      expect(entry.avatarId, 'night_runner');

      final copied = entry.copyWith(avatarId: 'apex_wolf');
      expect(copied.avatarId, 'apex_wolf');
      expect(copied.distanceM, 10000);

      final map = entry.toMap();
      expect(map['avatarId'], 'night_runner');

      final restored = LeaderboardEntry.fromMap(map);
      expect(restored.avatarId, 'night_runner');
    });

    test('LeaderboardEntry without avatarId deserializes with null', () {
      final entry = LeaderboardEntry.fromMap({
        'uid': 'u2',
        'displayName': 'Old User',
        'city': 'Jakarta',
        'weekKey': '2026-11-16',
        'distanceM': 5000.0,
        'runCount': 1,
        'updatedAt': '2026-11-20T00:00:00.000Z',
      });
      expect(entry.avatarId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // NearPaceAvatar Widget
  // ---------------------------------------------------------------------------

  group('Phase 3 - NearPaceAvatar Widget', () {
    testWidgets('renders custom painter for valid avatarId', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NearPaceTheme.dark(),
          home: const Scaffold(
            body: Center(
              child: NearPaceAvatar(
                avatarId: 'volt_sprinter',
                name: 'Test Runner',
                size: 56,
              ),
            ),
          ),
        ),
      );

      // Should find a ClipOval wrapping the custom painter inside NearPaceAvatar
      expect(find.byType(ClipOval), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NearPaceAvatar),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders initials fallback for null avatarId', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NearPaceTheme.dark(),
          home: const Scaffold(
            body: Center(
              child: NearPaceAvatar(
                avatarId: null,
                name: 'Ahmad Rasyid',
                size: 44,
              ),
            ),
          ),
        ),
      );

      // Should show initials "AR"
      expect(find.text('AR'), findsOneWidget);
      // Should NOT use ClipOval (that's the custom painter path)
      expect(find.byType(ClipOval), findsNothing);
    });

    testWidgets('renders initials fallback for unknown avatarId', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NearPaceTheme.dark(),
          home: const Scaffold(
            body: Center(
              child: NearPaceAvatar(
                avatarId: 'nonexistent_id',
                name: 'Single',
                size: 44,
              ),
            ),
          ),
        ),
      );

      // Unknown avatar falls back to initials
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('all 12 avatar IDs render without errors', (tester) async {
      for (final avatar in kNearPaceAvatars) {
        await tester.pumpWidget(
          MaterialApp(
            theme: NearPaceTheme.dark(),
            home: Scaffold(
              body: Center(
                child: NearPaceAvatar(
                  avatarId: avatar.id,
                  name: avatar.name,
                  size: 56,
                ),
              ),
            ),
          ),
        );
        // Each should render a ClipOval
        expect(
          find.byType(ClipOval),
          findsOneWidget,
          reason: 'Avatar ${avatar.id} should render a custom painter',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // AvatarPickerSheet
  // ---------------------------------------------------------------------------

  group('Phase 3 - AvatarPickerSheet', () {
    testWidgets('opens modal, filters categories, and selects an avatar', (
      tester,
    ) async {
      String? pickedAvatarId;
      await tester.pumpWidget(
        MaterialApp(
          theme: NearPaceTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  pickedAvatarId = await AvatarPickerSheet.show(context);
                },
                child: const Text('Pick Avatar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick Avatar'));
      await tester.pumpAndSettle();

      // Default preview + grid shows Volt Sprinter
      expect(find.text('Volt Sprinter'), findsWidgets);

      // Filter to mascots and select Apex Wolf
      await tester.tap(find.text('Mascots (4)'));
      await tester.pumpAndSettle();

      expect(find.text('Apex Wolf'), findsOneWidget);
      await tester.tap(find.text('Apex Wolf'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select Apex Wolf'));
      await tester.pumpAndSettle();

      expect(pickedAvatarId, 'apex_wolf');
    });
  });

  // ---------------------------------------------------------------------------
  // ShareActivitySheet
  // ---------------------------------------------------------------------------

  group('Phase 3 - ShareActivitySheet', () {
    testWidgets(
      'renders transparent sticker with checkerboard outside RepaintBoundary, overlay tone switch, and Dark Brand Card mode',
      (tester) async {
        final activity = Activity(
          id: 'share_test',
          startedAt: DateTime.utc(2026, 11, 24, 6, 0),
          endedAt: DateTime.utc(2026, 11, 24, 6, 30),
          distanceM: 5000,
          durationS: 1800,
          avgPaceSecPerKm: 360.0,
          city: 'Tangerang Selatan',
          route: const [
            GeoPointLite(latitude: -5.145, longitude: 119.430),
            GeoPointLite(latitude: -5.148, longitude: 119.435),
            GeoPointLite(latitude: -5.150, longitude: 119.440),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: NearPaceTheme.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      ShareActivitySheet.show(context, activity: activity),
                  child: const Text('Share'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();

        // No layout overflow
        expect(tester.takeException(), isNull);

        // Mode selector chips should be present
        expect(find.textContaining('Transparent'), findsOneWidget);
        expect(find.textContaining('Dark'), findsOneWidget);

        // Overlay tone options in transparent sticker mode
        expect(find.text('Volt #B7F36B'), findsOneWidget);
        expect(find.text('Pure White'), findsOneWidget);

        // Checkerboard preview is outside RepaintBoundary
        final checkerboardFinder = find.byKey(
          const ValueKey('share-preview-checkerboard'),
        );
        expect(checkerboardFinder, findsOneWidget);
        final boundaryFinder = find.descendant(
          of: checkerboardFinder,
          matching: find.byType(RepaintBoundary),
        );
        expect(boundaryFinder, findsOneWidget);

        // RouteSketch inside RepaintBoundary uses transparent background
        final routeSketch = tester.widget<RouteSketch>(
          find.descendant(
            of: boundaryFinder,
            matching: find.byType(RouteSketch),
          ),
        );
        expect(routeSketch.transparentBackground, isTrue);

        // Switch overlay tone to Pure White
        await tester.tap(find.text('Pure White'));
        await tester.pumpAndSettle();
        final whiteRouteSketch = tester.widget<RouteSketch>(
          find.descendant(
            of: boundaryFinder,
            matching: find.byType(RouteSketch),
          ),
        );
        expect(whiteRouteSketch.strokeColorOverride, const Color(0xFFF2F5F0));

        // Switch to Dark Brand Card
        await tester.tap(find.text('Dark Brand Card'));
        await tester.pumpAndSettle();
        expect(find.text('Pure White'), findsNothing);
        final darkRouteSketch = tester.widget<RouteSketch>(
          find.descendant(
            of: boundaryFinder,
            matching: find.byType(RouteSketch),
          ),
        );
        expect(darkRouteSketch.transparentBackground, isFalse);

        // Action buttons
        expect(find.text('Save Image'), findsOneWidget);
        expect(find.text('Share'), findsWidgets);
      },
    );
  });
}
