import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'config/firebase_bootstrap.dart';
import 'config/firebase_config.dart';
import 'state/nearpace_controller.dart';
import 'theme/nearpace_spacing.dart';
import 'theme/nearpace_theme.dart';
import 'ui/screens/app_shell.dart';
import 'ui/screens/auth_screen.dart';

/// Root NearPace Flutter application wiring theme, state controller, and the
/// authentication gate.
class NearPaceApp extends StatelessWidget {
  NearPaceApp({
    super.key,
    FirebaseBootstrapStatus? firebaseStatus,
    this.startSignedIn = false,
    this.clockNow,
  }) : firebaseStatus =
           firebaseStatus ?? FirebaseUnconfigured(FirebaseConfig.missingKeys);

  final FirebaseBootstrapStatus firebaseStatus;
  final bool startSignedIn;
  final DateTime? clockNow;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NearPaceController>(
      create: (_) => NearPaceController(
        firebaseStatus: firebaseStatus,
        startSignedIn: startSignedIn,
        clockNow: clockNow,
      ),
      child: const _NearPaceMaterialApp(),
    );
  }
}

class _NearPaceMaterialApp extends StatelessWidget {
  const _NearPaceMaterialApp();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();

    return MaterialApp(
      title: 'NearPace',
      debugShowCheckedModeBanner: false,
      theme: NearPaceTheme.light(),
      darkTheme: NearPaceTheme.dark(),
      themeMode: controller.themeMode,
      home: AnimatedSwitcher(
        duration: NearPaceMotion.resolve(context, NearPaceMotion.standard),
        switchInCurve: NearPaceMotion.easeOut,
        child: controller.isSignedIn
            ? const AppShell(key: ValueKey('app-shell'))
            : const AuthScreen(key: ValueKey('auth-screen')),
      ),
    );
  }
}
