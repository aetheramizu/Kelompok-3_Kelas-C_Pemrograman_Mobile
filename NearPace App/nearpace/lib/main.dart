import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'config/firebase_bootstrap.dart';

export 'app.dart' show NearPaceApp;
export 'config/firebase_bootstrap.dart'
    show
        FirebaseBootstrapStatus,
        FirebaseInitFailed,
        FirebaseReady,
        FirebaseUnconfigured,
        bootstrapFirebase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseStatus = await bootstrapFirebase();
  runApp(NearPaceApp(firebaseStatus: firebaseStatus));
}
