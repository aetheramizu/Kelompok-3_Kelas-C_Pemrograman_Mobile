import 'package:firebase_core/firebase_core.dart';

import 'firebase_config.dart';

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
