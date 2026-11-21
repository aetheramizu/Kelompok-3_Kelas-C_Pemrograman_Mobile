/// Firebase configuration supplied at build time.
///
/// Nothing secret belongs in this file. Values are read from `--dart-define`
/// (or `--dart-define-from-file=dart_defines.json`) so the repository never
/// needs a committed `google-services.json` to compile.
class FirebaseConfig {
  const FirebaseConfig._();

  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );

  /// Android uses the numeric project number as `messagingSenderId`.
  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static Set<String> get missingKeys => {
    if (apiKey.isEmpty) 'FIREBASE_API_KEY',
    if (appId.isEmpty) 'FIREBASE_APP_ID',
    if (messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
    if (projectId.isEmpty) 'FIREBASE_PROJECT_ID',
  };
}
