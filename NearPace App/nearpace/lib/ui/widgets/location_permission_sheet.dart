import 'package:material_ui/material_ui.dart';

import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';

/// Foreground location rationale sheet displayed before acquiring GPS.
Future<LocationPermissionStatus?> showLocationPermissionSheet(
  BuildContext context, {
  required LocationPermissionStatus currentStatus,
}) {
  return showModalBottomSheet<LocationPermissionStatus>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _LocationPermissionSheet(currentStatus: currentStatus),
  );
}

class _LocationPermissionSheet extends StatelessWidget {
  const _LocationPermissionSheet({required this.currentStatus});

  final LocationPermissionStatus currentStatus;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final isPermanent = currentStatus == LocationPermissionStatus.deniedForever;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NearPaceSpacing.xl,
          NearPaceSpacing.xs,
          NearPaceSpacing.xl,
          NearPaceSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPermanent
                    ? colors.dangerSurface
                    : colors.deepGreenSurface,
                borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
              ),
              child: Icon(
                isPermanent
                    ? Icons.location_disabled_rounded
                    : Icons.my_location_rounded,
                color: isPermanent ? colors.danger : colors.performanceGreen,
              ),
            ),
            const SizedBox(height: NearPaceSpacing.md),
            Text(
              isPermanent
                  ? 'Location permission is turned off'
                  : 'Allow location while running',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: NearPaceSpacing.xs),
            Text(
              isPermanent
                  ? 'NearPace cannot record GPS distance or draw your route '
                        'sketch while location access is permanently denied. '
                        'Enable "While using the app" in Android settings.'
                  : 'NearPace reads GPS coordinates only while you record a '
                        'run in the foreground to calculate distance, pace, and '
                        'start-point weather.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: NearPaceSpacing.md),
            Container(
              padding: const EdgeInsets.all(NearPaceSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: NearPaceSpacing.xs),
                  Expanded(
                    child: Text(
                      'Your GPS route stays private and is never published to '
                      'the leaderboard.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NearPaceSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(LocationPermissionStatus.granted),
                child: Text(
                  isPermanent
                      ? 'Grant in preview (simulate settings)'
                      : 'Allow while using app',
                ),
              ),
            ),
            const SizedBox(height: NearPaceSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(LocationPermissionStatus.denied),
                    child: const Text('Deny'),
                  ),
                ),
                const SizedBox(width: NearPaceSpacing.xs),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(LocationPermissionStatus.deniedForever),
                    child: const Text('Deny forever'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
