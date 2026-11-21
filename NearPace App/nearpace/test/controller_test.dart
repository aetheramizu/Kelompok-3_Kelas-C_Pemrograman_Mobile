import 'package:flutter_test/flutter_test.dart';
import 'package:nearpace/config/firebase_bootstrap.dart';
import 'package:nearpace/domain/run_state.dart';
import 'package:nearpace/state/nearpace_controller.dart';

void main() {
  group('NearPaceController', () {
    late NearPaceController controller;

    setUp(() {
      controller = NearPaceController(
        firebaseStatus: const FirebaseUnconfigured({'FIREBASE_API_KEY'}),
        clockNow: DateTime(2026, 11, 21, 9, 0),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('starts signed out with seeded weekly activities', () {
      expect(controller.isSignedIn, isFalse);
      expect(controller.activities, isNotEmpty);
      expect(controller.weeklyActivities, isNotEmpty);
      expect(controller.weeklyDistanceMeters, greaterThan(0));
    });

    test('sign-up preview updates runner profile and signs in', () {
      controller.signUpLocalPreview(
        email: 'sara@example.com',
        displayName: 'Sara Hakim',
        city: 'Surabaya',
      );

      expect(controller.isSignedIn, isTrue);
      expect(controller.profile.displayName, 'Sara Hakim');
      expect(controller.profile.city, 'Surabaya');
      expect(controller.profile.showOnLeaderboard, isFalse);
    });

    test(
      'leaderboard includes runner only when opted in and filters by city',
      () {
        final uid = controller.profile.uid;
        expect(
          controller.allLeaderboardEntries.any((entry) => entry.uid == uid),
          isFalse,
        );

        controller.setShowOnLeaderboard(true);
        expect(
          controller.allLeaderboardEntries.any((entry) => entry.uid == uid),
          isTrue,
        );

        controller.setSelectedCity('Makassar');
        final makassar = controller.filteredLeaderboardEntries;
        expect(makassar, isNotEmpty);
        expect(makassar.every((e) => e.city == 'Makassar'), isTrue);
        expect(makassar.any((e) => e.uid == uid), isTrue);
      },
    );

    test(
      'enforces location permission and records full run lifecycle',
      () async {
        await controller.startRecording(acquireDelay: Duration.zero);
        expect(controller.runState, isA<RunFailed>());

        controller.setLocationPermission(LocationPermissionStatus.granted);
        expect(controller.runState, isA<RunIdle>());

        await controller.startRecording(acquireDelay: Duration.zero);
        expect(controller.runState, isA<RunActive>());
        expect((controller.runState as RunActive).paused, isFalse);

        controller.pauseRecording();
        expect((controller.runState as RunActive).paused, isTrue);

        controller.resumeRecording();
        expect((controller.runState as RunActive).paused, isFalse);

        final result = await controller.finishRecording(
          finalizeDelay: Duration.zero,
        );
        expect(result, isNotNull);
        expect(controller.runState, isA<RunIdle>());

        final beforeCount = controller.activities.length;
        controller.saveActivity(result!);
        expect(controller.activities.length, beforeCount + 1);
        expect(controller.activities.first.id, result.id);
      },
    );

    test('triggers and dismisses foreground notification banner', () {
      expect(controller.activeNotice, isNull);
      controller.triggerPreviewNotification(title: 'Test alert', body: 'Hello');
      expect(controller.activeNotice?.title, 'Test alert');

      controller.dismissNotification();
      expect(controller.activeNotice, isNull);
    });
  });
}
