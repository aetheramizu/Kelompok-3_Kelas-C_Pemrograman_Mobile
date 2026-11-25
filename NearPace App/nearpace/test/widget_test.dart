import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nearpace/main.dart';
import 'package:nearpace/ui/widgets/city_picker_sheet.dart';

void main() {
  final fixedClock = DateTime(2026, 11, 21, 9, 0);

  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('Firebase bootstrap status visibility', () {
    testWidgets('shows unconfigured Firebase status on auth screen', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        NearPaceApp(
          firebaseStatus: const FirebaseUnconfigured({
            'FIREBASE_API_KEY',
            'FIREBASE_PROJECT_ID',
          }),
          clockNow: fixedClock,
        ),
      );

      expect(find.text('NearPace'), findsOneWidget);
      expect(
        find.text('Firebase not configured (local preview)'),
        findsOneWidget,
      );
      expect(find.textContaining('FIREBASE_API_KEY'), findsOneWidget);
    });

    testWidgets('hides Firebase status banner when Firebase is initialized', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        NearPaceApp(
          firebaseStatus: const FirebaseReady(),
          clockNow: fixedClock,
        ),
      );

      expect(find.text('NearPace'), findsOneWidget);
      expect(find.text('Firebase ready'), findsNothing);
    });

    testWidgets('shows failure state when Firebase initialization fails', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        NearPaceApp(
          firebaseStatus: const FirebaseInitFailed('invalid-options'),
          clockNow: fixedClock,
        ),
      );

      expect(find.text('Firebase initialization failed'), findsOneWidget);
      expect(find.textContaining('invalid-options'), findsOneWidget);
    });
  });

  group('Auth and main shell navigation', () {
    testWidgets('validates empty sign-in form and signs in with credentials', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(NearPaceApp(clockNow: fixedClock));

      await tester.ensureVisible(find.text('Sign in (preview)'));
      await tester.tap(find.text('Sign in (preview)'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).first,
        'alief@nearpace.id',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign in (preview)'));
      await tester.pumpAndSettle();

      expect(find.text('Ready, Alief?'), findsOneWidget);
      expect(find.text('Set a run reminder'), findsOneWidget);
      expect(find.text('Firebase ready'), findsNothing);
      expect(find.text('Local preview'), findsNothing);
      expect(find.text('THIS WEEK'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Recent runs'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('home-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Recent runs'), findsOneWidget);
    });

    testWidgets('switches across Home, History, Ranks, and Profile tabs', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        NearPaceApp(startSignedIn: true, clockNow: fixedClock),
      );

      // Home -> History
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Private saved runs, newest first'), findsOneWidget);

      // History filter chip interaction
      await tester.tap(find.text('5 km+'));
      await tester.pumpAndSettle();
      expect(find.text('5 km+'), findsOneWidget);

      // History -> Leaderboard (Ranks)
      await tester.tap(find.text('Ranks'));
      await tester.pumpAndSettle();
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('Join this week\'s leaderboard'), findsOneWidget);

      // Join leaderboard directly from prompt
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('You'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('leaderboard-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('You'), findsOneWidget);

      // Scroll back to top and filter by Makassar
      await tester.drag(
        find.byKey(const ValueKey('leaderboard-scroll')),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Makassar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Makassar').first);
      await tester.pumpAndSettle();
      expect(find.text('Nadia Rahman'), findsOneWidget);

      // Ranks -> Profile
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Personal bests'), findsOneWidget);
      expect(find.text('Connection status'), findsNothing);
      expect(find.text('Topic: nearpace_updates'), findsNothing);

      final profileScrollable = find
          .descendant(
            of: find.byKey(const ValueKey('profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;

      // Enable run reminders and send a test reminder
      await tester.scrollUntilVisible(
        find.text('Run reminders'),
        200,
        scrollable: profileScrollable,
      );
      await tester.tap(find.text('Run reminders'));
      await tester.pumpAndSettle();
      expect(find.text('Repeat days'), findsOneWidget);
      expect(find.text('Reminder time'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Send test reminder'),
        200,
        scrollable: profileScrollable,
      );
      await tester.ensureVisible(find.text('Send test reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send test reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Huss, Huss, Huss! Time to run 🏃'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss notification'));
      await tester.pumpAndSettle();
      expect(find.text('Huss, Huss, Huss! Time to run 🏃'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Show on weekly leaderboard'),
        200,
        scrollable: profileScrollable,
      );
      expect(find.text('Show on weekly leaderboard'), findsOneWidget);
    });
  });

  group('Run recording and result flow', () {
    testWidgets(
      'walks permission sheet -> active -> pause -> resume -> finish -> save',
      (tester) async {
        usePhoneViewport(tester);
        await tester.pumpWidget(
          NearPaceApp(startSignedIn: true, clockNow: fixedClock),
        );

        // Open recorder from Home quick start card.
        await tester.tap(find.text('Start a run'));
        await tester.pumpAndSettle();
        expect(find.text('Record run'), findsOneWidget);

        // Tap circular Start run CTA -> triggers location permission sheet.
        await tester.tap(find.text('Start run'));
        await tester.pumpAndSettle();
        expect(find.text('Allow location while running'), findsOneWidget);

        // Grant permission -> acquires GPS fix and transitions to active.
        await tester.tap(find.text('Allow while using app'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('Running'), findsOneWidget);
        expect(find.text('GPS active'), findsOneWidget);

        // Pause -> Resume.
        await tester.tap(find.text('Pause'));
        await tester.pump();
        expect(find.text('Resume'), findsOneWidget);

        await tester.tap(find.text('Resume'));
        await tester.pump();
        expect(find.text('Pause'), findsOneWidget);

        // Finish -> Confirm -> Result screen -> Save run.
        await tester.tap(find.text('Finish'));
        await tester.pumpAndSettle();
        expect(find.text('Finish this run?'), findsOneWidget);

        await tester.tap(find.text('Finish run'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text('Run summary'), findsOneWidget);
        expect(find.text('Weather data by Open-Meteo'), findsOneWidget);

        await tester.tap(find.text('Save run'));
        await tester.pumpAndSettle();

        // Back on Home shell after saving.
        expect(find.text('Ready, Alief?'), findsOneWidget);
      },
    );

    testWidgets('handles location permission denied recovery state', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        NearPaceApp(startSignedIn: true, clockNow: fixedClock),
      );

      await tester.tap(find.text('Start a run'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start run'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot start recording'), findsOneWidget);
      expect(find.text('Update location permission'), findsOneWidget);
    });

    testWidgets('displays weather unavailable fallback on saved run', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        NearPaceApp(startSignedIn: true, clockNow: fixedClock),
      );

      // Go to History and open the 5th seeded run which has null weather.
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('3.60 km'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('history-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('3.60 km'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3.60 km'));
      await tester.pumpAndSettle();

      expect(find.text('Activity detail'), findsOneWidget);
      expect(find.text('Conditions unavailable'), findsOneWidget);
    });
  });

  group('Responsive layout, text scaling, and theme switching', () {
    testWidgets('renders cleanly on narrow 360px phone at 1.6x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.6),
          ),
          child: NearPaceApp(startSignedIn: true, clockNow: fixedClock),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Home tab overflowed');

      for (final tab in ['History', 'Ranks', 'Profile']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab tab overflowed');
      }
    });

    testWidgets('renders cleanly in landscape and switches to Light theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        NearPaceApp(startSignedIn: true, clockNow: fixedClock),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Light'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('Light'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
    testWidgets('edits profile name/city and signs out back to auth screen', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        NearPaceApp(startSignedIn: true, clockNow: fixedClock),
      );

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.text('Save changes'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Rina Kartika',
      );
      await tester.tap(find.text('City (optional)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(CityPickerSheet),
          matching: find.byType(TextField),
        ),
        'Bandung',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(CityPickerSheet),
              matching: find.widgetWithText(ListTile, 'Bandung'),
            )
            .first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Rina Kartika'), findsOneWidget);
      expect(find.text('Bandung'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Sign out'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out of NearPace?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in (preview)'), findsOneWidget);
    });
  });
}
