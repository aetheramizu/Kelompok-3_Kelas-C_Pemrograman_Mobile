import 'package:flutter_test/flutter_test.dart';
import 'package:nearpace/main.dart';

void main() {
  testWidgets('renders foundation shell when Firebase is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      NearPaceApp(
        firebaseStatus: const FirebaseUnconfigured({
          'FIREBASE_API_KEY',
          'FIREBASE_PROJECT_ID',
        }),
      ),
    );

    expect(find.text('NearPace'), findsOneWidget);
    expect(find.text('NearPace setup foundation'), findsOneWidget);
    expect(find.text('Firebase not configured (optional)'), findsOneWidget);
    expect(find.textContaining('FIREBASE_API_KEY'), findsOneWidget);
  });

  testWidgets('renders ready state when Firebase is initialized', (
    tester,
  ) async {
    await tester.pumpWidget(NearPaceApp(firebaseStatus: const FirebaseReady()));

    expect(find.text('Firebase ready'), findsOneWidget);
  });

  testWidgets('renders failure state when Firebase initialization fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      NearPaceApp(firebaseStatus: const FirebaseInitFailed('invalid-options')),
    );

    expect(find.text('Firebase initialization failed'), findsOneWidget);
    expect(find.text('invalid-options'), findsOneWidget);
  });
}
