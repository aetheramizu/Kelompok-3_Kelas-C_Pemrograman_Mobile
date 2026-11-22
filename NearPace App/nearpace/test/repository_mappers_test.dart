import 'package:flutter_test/flutter_test.dart';
import 'package:nearpace/data/repositories/activity_repository.dart';
import 'package:nearpace/domain/activity.dart';
import 'package:nearpace/domain/geo_point.dart';
import 'package:nearpace/domain/leaderboard_entry.dart';
import 'package:nearpace/domain/user_profile.dart';
import 'package:nearpace/domain/weather.dart';

void main() {
  group('Route Capping & Activity Serialization', () {
    test('capRoute preserves points when length <= maxPoints', () {
      final points = List.generate(
        50,
        (i) => GeoPointLite(
          latitude: -5.0 + i * 0.001,
          longitude: 119.0 + i * 0.001,
        ),
      );

      final capped = FirestoreActivityRepository.capRoute(
        points,
        maxPoints: 250,
      );
      expect(capped.length, 50);
      expect(capped.first.latitude, points.first.latitude);
      expect(capped.last.latitude, points.last.latitude);
    });

    test('capRoute downsamples large routes to maxPoints while preserving start & end', () {
      final points = List.generate(
        600,
        (i) => GeoPointLite(
          latitude: -5.0 + i * 0.0001,
          longitude: 119.0 + i * 0.0001,
        ),
      );

      final capped = FirestoreActivityRepository.capRoute(
        points,
        maxPoints: 250,
      );
      expect(capped.length, 250);
      expect(capped.first.latitude, points.first.latitude);
      expect(capped.first.longitude, points.first.longitude);
      expect(capped.last.latitude, points.last.latitude);
      expect(capped.last.longitude, points.last.longitude);
    });

    test('Activity domain toMap and fromMap round-trip correctly', () {
      final now = DateTime(2026, 11, 22, 7, 30);
      final activity = Activity(
        id: 'act-123',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 30)),
        distanceM: 5240,
        durationS: 1800,
        avgPaceSecPerKm: 343.5,
        route: const [
          GeoPointLite(latitude: -5.14, longitude: 119.43),
          GeoPointLite(latitude: -5.15, longitude: 119.44),
        ],
        weather: WeatherSnapshot(
          temperatureC: 28.5,
          apparentC: 30.5,
          code: 1,
          fetchedAt: now,
        ),
      );

      final map = activity.toMap();
      expect(map['distanceM'], 5240);
      expect(map['durationS'], 1800);

      final restored = Activity.fromMap('act-123', map);
      expect(restored.id, 'act-123');
      expect(restored.distanceM, 5240);
      expect(restored.durationS, 1800);
      expect(restored.avgPaceSecPerKm, 343.5);
      expect(restored.route.length, 2);
      expect(restored.weather?.temperatureC, 28.5);
    });
  });

  group('LeaderboardEntry & Privacy Guard', () {
    test('LeaderboardEntry toMap excludes email, fcmToken, and GPS route', () {
      final now = DateTime(2026, 11, 22, 8, 0);
      final entry = LeaderboardEntry(
        uid: 'user-789',
        displayName: 'Ahmad Runner',
        city: 'Makassar',
        weekKey: '2026-11-16',
        distanceM: 21500,
        runCount: 4,
        updatedAt: now,
      );

      final map = entry.toMap();
      expect(map.containsKey('email'), isFalse);
      expect(map.containsKey('fcmToken'), isFalse);
      expect(map.containsKey('route'), isFalse);

      expect(map['uid'], 'user-789');
      expect(map['displayName'], 'Ahmad Runner');
      expect(map['city'], 'Makassar');
      expect(map['weekKey'], '2026-11-16');
      expect(map['distanceM'], 21500);
      expect(map['runCount'], 4);

      expect(entry.documentId, '2026-11-16_user-789');
      expect(entry.initials, 'AR');
      expect(entry.distanceKm, 21.5);
    });
  });

  group('UserProfile', () {
    test('extracts initials cleanly for single and multiple names', () {
      const p1 = UserProfile(
        uid: '1',
        email: 'test@example.com',
        displayName: 'Budi Santoso',
        city: 'Jakarta',
        showOnLeaderboard: false,
      );
      expect(p1.initials, 'BS');

      const p2 = UserProfile(
        uid: '2',
        email: 'test@example.com',
        displayName: 'Alief',
        city: 'Makassar',
        showOnLeaderboard: false,
      );
      expect(p2.initials, 'A');

      const p3 = UserProfile(
        uid: '3',
        email: 'test@example.com',
        displayName: '   ',
        city: '',
        showOnLeaderboard: false,
      );
      expect(p3.initials, 'N');
    });

    test('UserProfile toMap / fromMap round-trip correctly', () {
      const profile = UserProfile(
        uid: 'user-456',
        email: 'runner@nearpace.com',
        displayName: 'Dewi Lestari',
        city: 'Bandung',
        showOnLeaderboard: true,
        fcmToken: 'fcm-sample-token-123',
      );

      final map = profile.toMap();
      expect(map['email'], 'runner@nearpace.com');
      expect(map['displayName'], 'Dewi Lestari');
      expect(map['city'], 'Bandung');
      expect(map['showOnLeaderboard'], isTrue);
      expect(map['fcmToken'], 'fcm-sample-token-123');

      final restored = UserProfile.fromMap('user-456', map);
      expect(restored.uid, 'user-456');
      expect(restored.email, profile.email);
      expect(restored.displayName, profile.displayName);
      expect(restored.city, profile.city);
      expect(restored.showOnLeaderboard, isTrue);
      expect(restored.fcmToken, 'fcm-sample-token-123');
    });
  });
}
