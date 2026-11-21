import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';

import 'config/firebase_config.dart';

/// Bootstrap state for optional Firebase initialization.
sealed class FirebaseBootstrapStatus {
  const FirebaseBootstrapStatus();
}

final class FirebaseUnconfigured extends FirebaseBootstrapStatus {
  const FirebaseUnconfigured(this.missingKeys);

  final Set<String> missingKeys;
}

final class FirebaseReady extends FirebaseBootstrapStatus {
  const FirebaseReady();
}

final class FirebaseInitFailed extends FirebaseBootstrapStatus {
  const FirebaseInitFailed(this.message);

  final String message;
}

Future<FirebaseBootstrapStatus> bootstrapFirebase() async {
  if (!FirebaseConfig.isConfigured) {
    return FirebaseUnconfigured(FirebaseConfig.missingKeys);
  }

  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: FirebaseConfig.apiKey,
        appId: FirebaseConfig.appId,
        messagingSenderId: FirebaseConfig.messagingSenderId,
        projectId: FirebaseConfig.projectId,
        storageBucket: FirebaseConfig.storageBucket.isEmpty
            ? null
            : FirebaseConfig.storageBucket,
        authDomain: FirebaseConfig.authDomain.isEmpty
            ? null
            : FirebaseConfig.authDomain,
      ),
    );
    return const FirebaseReady();
  } catch (error) {
    return FirebaseInitFailed(error.toString());
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseStatus = await bootstrapFirebase();
  runApp(NearPaceApp(firebaseStatus: firebaseStatus));
}

class NearPaceApp extends StatelessWidget {
  NearPaceApp({super.key, FirebaseBootstrapStatus? firebaseStatus})
    : firebaseStatus =
          firebaseStatus ?? FirebaseUnconfigured(FirebaseConfig.missingKeys);

  final FirebaseBootstrapStatus firebaseStatus;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NearPace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
      ),
      home: _FoundationScreen(firebaseStatus: firebaseStatus),
    );
  }
}

class _FoundationScreen extends StatelessWidget {
  const _FoundationScreen({required this.firebaseStatus});

  final FirebaseBootstrapStatus firebaseStatus;

  @override
  Widget build(BuildContext context) {
    final (statusTitle, statusDetail) = switch (firebaseStatus) {
      FirebaseReady() => (
        'Firebase ready',
        'Firebase Core initialized from build-time configuration.',
      ),
      FirebaseUnconfigured(:final missingKeys) => (
        'Firebase not configured (optional)',
        missingKeys.isEmpty
            ? 'Provide Firebase --dart-define values to enable backend features.'
            : 'Missing keys: ${missingKeys.join(', ')}',
      ),
      FirebaseInitFailed(:final message) => (
        'Firebase initialization failed',
        message,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('NearPace')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NearPace setup foundation',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                statusTitle,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                statusDetail,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
