import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../config/firebase_bootstrap.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/metric_tile.dart';
import '../widgets/nearpace_card.dart';
import '../widgets/state_views.dart';

/// Runner profile and settings screen covering display name, optional city,
/// weekly leaderboard opt-in, appearance, foreground notification preview,
/// Firebase configuration status, and sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _openEditProfileSheet(
    BuildContext context,
    NearPaceController controller,
  ) async {
    final result = await showModalBottomSheet<({String name, String city})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditProfileSheet(
        initialName: controller.profile.displayName,
        initialCity: controller.profile.city,
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await controller.updateProfile(
        displayName: result.name,
        city: result.city,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.isLocalPreview
                ? 'Profile updated for this preview session.'
                : 'Profile updated successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    }
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    NearPaceController controller,
  ) async {
    final signOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of NearPace?'),
        content: const Text(
          'You will return to the sign-in screen. Local preview changes stay '
          'only for the active app session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.npColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (signOut == true) {
      controller.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final profile = controller.profile;

    final (
      firebaseTitle,
      firebaseDetail,
      firebaseColor,
      firebaseBg,
    ) = switch (controller.firebaseStatus) {
      FirebaseReady() => (
        'Firebase Core ready',
        'Build-time Firebase options were initialized. Auth, Firestore, '
            'and FCM wiring remain ready for backend integration.',
        colors.performanceGreen,
        colors.deepGreenSurface,
      ),
      FirebaseUnconfigured(:final missingKeys) => (
        'Firebase not configured',
        missingKeys.isEmpty
            ? 'Running in local UI preview mode.'
            : 'Missing build-time keys: ${missingKeys.join(', ')}. '
                  'Running in local UI preview mode without cloud sync.',
        colors.textSecondary,
        colors.surfaceElevated,
      ),
      FirebaseInitFailed(:final message) => (
        'Firebase initialization failed',
        'Falling back to local preview mode. Error: $message',
        colors.danger,
        colors.dangerSurface,
      ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = NearPaceSpacing.pageGutter(constraints.maxWidth);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: NearPaceSpacing.maxContentWidth,
            ),
            child: CustomScrollView(
              key: const ValueKey('profile-scroll'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    NearPaceSpacing.md,
                    gutter,
                    NearPaceSpacing.xxxl,
                  ),
                  sliver: SliverList.list(
                    children: [
                      Text('Profile', style: textTheme.headlineMedium),
                      const SizedBox(height: NearPaceSpacing.md),

                      // Runner identity card.
                      NearPaceCard(
                        padding: const EdgeInsets.all(NearPaceSpacing.lg),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colors.deepGreenSurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.accentText.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    profile.initials,
                                    style: textTheme.titleLarge?.copyWith(
                                      color: colors.accentText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: NearPaceSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        profile.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      StatusPill(
                                        label: profile.city.isEmpty
                                            ? 'No city set'
                                            : profile.city,
                                        icon: Icons.location_city_rounded,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: NearPaceSpacing.md),
                            Divider(color: colors.border),
                            const SizedBox(height: NearPaceSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: MetricTile(
                                    label: 'Saved runs',
                                    value: '${controller.activities.length}',
                                    compact: true,
                                  ),
                                ),
                                Expanded(
                                  child: MetricTile(
                                    label: 'Total distance',
                                    value: NearPaceFormatters.distanceKmValue(
                                      controller.totalDistanceMeters,
                                      decimals: 1,
                                    ),
                                    unit: 'km',
                                    highlight: true,
                                    compact: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: NearPaceSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _openEditProfileSheet(context, controller),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Edit name and city'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.lg),

                      // Privacy & Leaderboard.
                      Text('Privacy', style: textTheme.titleMedium),
                      const SizedBox(height: NearPaceSpacing.xs),
                      NearPaceCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: NearPaceSpacing.md,
                          vertical: NearPaceSpacing.xs,
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Show on weekly leaderboard',
                            style: textTheme.titleSmall,
                          ),
                          subtitle: Text(
                            'Shares only display name, city, and weekly '
                            'distance. Email and GPS routes stay private.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          value: profile.showOnLeaderboard,
                          onChanged: (value) async {
                            try {
                              await controller.setShowOnLeaderboard(value);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to update leaderboard settings: $e',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.lg),

                      // Appearance.
                      Text('Appearance', style: textTheme.titleMedium),
                      const SizedBox(height: NearPaceSpacing.xs),
                      NearPaceCard(
                        padding: const EdgeInsets.all(NearPaceSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Theme', style: textTheme.titleSmall),
                            const SizedBox(height: NearPaceSpacing.xs),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<ThemeMode>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Dark', maxLines: 1),
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Light', maxLines: 1),
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('System', maxLines: 1),
                                    ),
                                  ),
                                ],
                                selected: {controller.themeMode},
                                onSelectionChanged: (selection) {
                                  if (selection.isNotEmpty) {
                                    controller.setThemeMode(selection.first);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.lg),

                      // Notifications (FCM foreground banner UI).
                      Text('Notifications', style: textTheme.titleMedium),
                      const SizedBox(height: NearPaceSpacing.xs),
                      NearPaceCard(
                        padding: const EdgeInsets.all(NearPaceSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 20,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: NearPaceSpacing.xs),
                                Expanded(
                                  child: Text(
                                    'Topic: nearpace_updates',
                                    style: textTheme.titleSmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: NearPaceSpacing.xxs),
                            Text(
                              'Foreground alerts render as an in-app banner. '
                              'Console FCM delivery activates once Firebase '
                              'push is connected.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            if (controller.isLocalPreview) ...[
                              const SizedBox(height: NearPaceSpacing.sm),
                              OutlinedButton.icon(
                                onPressed: () {
                                  controller.triggerPreviewNotification(
                                    title: 'NearPace update',
                                    body:
                                        'Weekly leaderboard resets Monday at '
                                        '00:00 local time.',
                                  );
                                },
                                icon: const Icon(
                                  Icons.campaign_outlined,
                                  size: 18,
                                ),
                                label: const Text('Preview foreground banner'),
                              ),
                            ] else ...[
                              const SizedBox(height: NearPaceSpacing.xs),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: colors.performanceGreen,
                                  ),
                                  const SizedBox(width: NearPaceSpacing.xxs),
                                  Text(
                                    'Live FCM notifications active',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.performanceGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.lg),

                      // Backend connection status (honest transparency).
                      Text('Connection status', style: textTheme.titleMedium),
                      const SizedBox(height: NearPaceSpacing.xs),
                      NearPaceCard(
                        backgroundColor: firebaseBg,
                        borderColor: firebaseColor.withValues(alpha: 0.35),
                        padding: const EdgeInsets.all(NearPaceSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              controller.firebaseStatus is FirebaseReady
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_off_outlined,
                              size: 20,
                              color: firebaseColor,
                            ),
                            const SizedBox(width: NearPaceSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    firebaseTitle,
                                    style: textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    firebaseDetail,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.xl),

                      // Sign out.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.danger,
                            side: BorderSide(
                              color: colors.danger.withValues(alpha: 0.5),
                            ),
                          ),
                          onPressed: () => _confirmSignOut(context, controller),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Sign out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.initialName,
    required this.initialCity,
  });

  final String initialName;
  final String initialCity;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _cityController = TextEditingController(text: widget.initialCity);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          NearPaceSpacing.xl,
          NearPaceSpacing.xs,
          NearPaceSpacing.xl,
          NearPaceSpacing.xl + bottomInset,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit profile', style: textTheme.titleLarge),
              const SizedBox(height: NearPaceSpacing.xs),
              Text(
                'Display name and city appear on the weekly leaderboard only '
                'if you opt in.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: NearPaceSpacing.md),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'e.g. Alief Pratama',
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Enter a display name.';
                  if (trimmed.length < 2) {
                    return 'Display name must be at least 2 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: NearPaceSpacing.sm),
              TextFormField(
                controller: _cityController,
                textInputAction: TextInputAction.done,
                maxLength: 60,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'City (optional)',
                  hintText: 'e.g. Makassar',
                ),
              ),
              const SizedBox(height: NearPaceSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: NearPaceSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
