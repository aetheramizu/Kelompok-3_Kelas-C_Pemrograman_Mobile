import 'package:flutter_test/flutter_test.dart';
import 'package:nearpace/config/firebase_bootstrap.dart';
import 'package:nearpace/data/repositories/activity_repository.dart';
import 'package:nearpace/data/repositories/auth_repository.dart';
import 'package:nearpace/data/repositories/leaderboard_repository.dart';
import 'package:nearpace/data/repositories/profile_repository.dart';
import 'package:nearpace/data/repositories/weather_repository.dart';
import 'package:nearpace/domain/user_profile.dart';
import 'package:nearpace/services/location_tracking_service.dart';
import 'package:nearpace/services/push_notification_service.dart';
import 'package:nearpace/state/nearpace_controller.dart';

void main() {
  group('Auth Integration & Controller Lifecycle', () {
    late MockAuthRepository mockAuth;
    late MockProfileRepository mockProfile;
    late MockActivityRepository mockActivity;
    late MockLeaderboardRepository mockLeaderboard;
    late MockWeatherRepository mockWeather;
    late SimulatedLocationService mockLocation;
    late NoopPushNotificationService mockPush;
    late NearPaceController controller;

    setUp(() {
      mockAuth = MockAuthRepository();
      mockProfile = MockProfileRepository(
        initialProfile: const UserProfile(
          uid: 'user-001',
          email: 'initial@nearpace.com',
          displayName: 'Initial Runner',
          city: 'Makassar',
          showOnLeaderboard: false,
        ),
      );
      mockActivity = MockActivityRepository();
      mockLeaderboard = MockLeaderboardRepository();
      mockWeather = MockWeatherRepository();
      mockLocation = SimulatedLocationService();
      mockPush = NoopPushNotificationService();

      controller = NearPaceController(
        firebaseStatus: const FirebaseReady(),
        isLocalPreview: false,
        authRepository: mockAuth,
        profileRepository: mockProfile,
        activityRepository: mockActivity,
        leaderboardRepository: mockLeaderboard,
        weatherRepository: mockWeather,
        locationService: mockLocation,
        pushService: mockPush,
      );
    });

    tearDown(() {
      controller.dispose();
      mockAuth.dispose();
      mockProfile.dispose();
      mockActivity.dispose();
      mockLeaderboard.dispose();
      mockLocation.dispose();
      mockPush.dispose();
    });

    test('signs up new account and sets up initial profile', () async {
      await controller.signUp(
        email: 'budi@nearpace.com',
        password: 'password123',
        displayName: 'Budi Runner',
        city: 'Surabaya',
      );

      expect(controller.isSignedIn, isTrue);
      expect(controller.profile.displayName, 'Budi Runner');
      expect(controller.profile.city, 'Surabaya');
      expect(controller.profile.showOnLeaderboard, isFalse);
    });

    test('signs in existing user and updates state', () async {
      await controller.signIn(
        email: 'initial@nearpace.com',
        password: 'password123',
      );

      expect(controller.isSignedIn, isTrue);
      expect(controller.isAuthBusy, isFalse);
      expect(controller.authError, isNull);
    });

    test('signs out and resets session state', () async {
      await controller.signIn(
        email: 'initial@nearpace.com',
        password: 'password123',
      );
      expect(controller.isSignedIn, isTrue);

      await controller.signOut();
      expect(controller.isSignedIn, isFalse);
      expect(mockAuth.currentUid, isNull);
    });
  });
}
