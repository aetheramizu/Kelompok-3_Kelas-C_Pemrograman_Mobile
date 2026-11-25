import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nearpace/domain/activity.dart';
import 'package:nearpace/domain/geo_point.dart';
import 'package:nearpace/domain/leaderboard_entry.dart';
import 'package:nearpace/domain/user_profile.dart';
import 'package:nearpace/services/indonesian_cities.dart';
import 'package:nearpace/theme/nearpace_theme.dart';
import 'package:nearpace/ui/widgets/avatar_picker_sheet.dart';
import 'package:nearpace/ui/widgets/nearpace_avatar.dart';
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
  // Avatar Presets & Domain Model
  // ---------------------------------------------------------------------------

  group('Phase 3 - NearPace Avatars & Domain Models', () {
    test('kNearPaceAvatars has exactly 12 unique characters', () {
      expect(kNearPaceAvatars.length, 12);
      final ids = kNearPaceAvatars.map((a) => a.id).toSet();
      expect(ids.length, 12, reason: 'Each avatar must have a unique ID');
    });

    test('avatars span 8 runners and 4 mascots', () {
      final runners =
          kNearPaceAvatars.where((a) => a.category == 'runners').length;
      final mascots =
          kNearPaceAvatars.where((a) => a.category == 'mascots').length;
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
        avatarId: 'dawn_sprinter',
      );

      expect(profile.avatarId, 'dawn_sprinter');

      final copied = profile.copyWith(avatarId: 'trail_blazer');
      expect(copied.avatarId, 'trail_blazer');
      expect(copied.displayName, 'Test Runner');

      final map = profile.toMap();
      expect(map['avatarId'], 'dawn_sprinter');

      final restored = UserProfile.fromMap('u1', map);
      expect(restored.avatarId, 'dawn_sprinter');
      expect(restored.uid, 'u1');
    });

    test('LeaderboardEntry carries avatarId through copyWith and fromMap', () {
      final entry = LeaderboardEntry(
        uid: 'u1',
        displayName: 'Runner A',
        city: 'Bandung',
        weekKey: '2026-W48',
        distanceM: 10000,
        runCount: 3,
        updatedAt: DateTime.utc(2026, 11, 24),
        avatarId: 'night_owl',
      );

      expect(entry.avatarId, 'night_owl');

      final copied = entry.copyWith(avatarId: 'apex_wolf');
      expect(copied.avatarId, 'apex_wolf');
      expect(copied.distanceM, 10000);

      final map = entry.toMap();
      expect(map['avatarId'], 'night_owl');

      final restored = LeaderboardEntry.fromMap(map);
      expect(restored.avatarId, 'night_owl');
    });

    test('LeaderboardEntry without avatarId deserializes with null', () {
      final entry = LeaderboardEntry.fromMap({
        'uid': 'u2',
        'displayName': 'Old User',
        'city': 'Jakarta',
        'weekKey': '2026-W47',
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
                avatarId: 'dawn_sprinter',
                name: 'Test Runner',
                size: 56,
              ),
            ),
          ),
        ),
      );

      // Should find a ClipOval wrapping the custom painter
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);
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

    testWidgets('renders initials fallback for unknown avatarId',
        (tester) async {
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
    testWidgets('opens modal and shows all 12 avatars', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NearPaceTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AvatarPickerSheet.show(context),
                child: const Text('Pick Avatar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick Avatar'));
      await tester.pumpAndSettle();

      // All 12 avatar names should be visible in the grid
      expect(find.textContaining('Dawn Sprinter'), findsOneWidget);
      expect(find.textContaining('Apex Wolf'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // ShareActivitySheet
  // ---------------------------------------------------------------------------

  group('Phase 3 - ShareActivitySheet', () {
    testWidgets('renders with mode toggle and action buttons', (tester) async {
      final activity = Activity(
        id: 'share_test',
        startedAt: DateTime.utc(2026, 11, 24, 6, 0),
        endedAt: DateTime.utc(2026, 11, 24, 6, 30),
        distanceM: 5000,
        durationS: 1800,
        avgPaceSecPerKm: 360.0,
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

      // Mode selector chips should be present
      expect(find.textContaining('Transparent'), findsOneWidget);
      expect(find.textContaining('Dark'), findsOneWidget);

      // Action buttons
      expect(find.text('Save Image'), findsOneWidget);
      expect(find.text('Share'), findsWidgets); // button + the trigger text
    });
  });
}
