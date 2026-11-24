import 'package:material_ui/material_ui.dart';

import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../widgets/nearpace_logo.dart';

/// Branded Splash / Auth Bootstrap Gate displaying the NearPace brand identity
/// while Firebase Auth state and user profile bootstrap is in flight.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(NearPaceSpacing.radiusLg),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.12),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(child: NearPaceLogo(size: 72)),
            ),
            const SizedBox(height: NearPaceSpacing.lg),
            Text(
              'NearPace',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: NearPaceSpacing.xs),
            Text(
              'Hyperlocal running companion',
              style: textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: NearPaceSpacing.xxl),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
