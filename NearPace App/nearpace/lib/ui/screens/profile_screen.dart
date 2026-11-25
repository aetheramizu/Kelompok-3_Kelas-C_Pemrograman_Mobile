import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/run_reminder.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/city_picker_sheet.dart';
import '../widgets/metric_tile.dart';
import '../widgets/nearpace_avatar.dart';
import '../widgets/nearpace_card.dart';
import '../widgets/state_views.dart';

/// Runner profile and settings screen covering display name, optional city,
/// personal bests, run reminders, weekly updates, leaderboard privacy,
/// appearance, and sign out.
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    }
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    NearPaceController controller,
  ) async {
    final reminder = controller.profile.runReminder;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
    );
    if (picked == null || !context.mounted) return;
    await controller.updateRunReminder(
      reminder.copyWith(hour: picked.hour, minute: picked.minute),
    );
  }

  Future<void> _toggleWeekday(
    NearPaceController controller,
    int weekday,
  ) async {
    final reminder = controller.profile.runReminder;
    final updated = Set<int>.from(reminder.weekdays);
    if (updated.contains(weekday)) {
      updated.remove(weekday);
    } else {
      updated.add(weekday);
    }
    await controller.updateRunReminder(reminder.copyWith(weekdays: updated));
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
          'You will return to the sign-in screen. Sign back in anytime to '
          'access your saved runs.',
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
    final reminder = profile.runReminder;
    final hasRuns = controller.activities.isNotEmpty;
    final bestPace = controller.bestPaceSecPerKm;
    final nextReminderLabel = reminder.nextSummaryLabel(controller.now);

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
                                Stack(
                                  children: [
                                    NearPaceAvatar(
                                      avatarId: profile.avatarId,
                                      name: profile.displayName,
                                      size: 64,
                                      onTap: () async {
                                        final newAvatarId =
                                            await AvatarPickerSheet.show(
                                              context,
                                              currentAvatarId: profile.avatarId,
                                            );
                                        if (newAvatarId != null) {
                                          await controller.updateAvatar(
                                            newAvatarId,
                                          );
                                        }
                                      },
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: colors.accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colors.surface,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.edit_rounded,
                                          size: 11,
                                          color: colors.onAccent,
                                        ),
                                      ),
                                    ),
                                  ],
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
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openEditProfileSheet(
                                      context,
                                      controller,
                                    ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Edit profile'),
                                  ),
                                ),
                                const SizedBox(width: NearPaceSpacing.sm),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final newAvatarId =
                                          await AvatarPickerSheet.show(
                                            context,
                                            currentAvatarId: profile.avatarId,
                                          );
                                      if (newAvatarId != null) {
                                        await controller.updateAvatar(
                                          newAvatarId,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.face_retouching_natural_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Avatar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.lg),

                      // Personal Bests.
                      Text('Personal bests', style: textTheme.titleMedium),
                      const SizedBox(height: NearPaceSpacing.xs),
                      NearPaceCard(
                        padding: const EdgeInsets.all(NearPaceSpacing.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: MetricTile(
                                label: 'Longest run',
                                value: hasRuns
                                    ? NearPaceFormatters.distanceKmValue(
                                        controller.longestRunMeters,
                                        decimals: 1,
                                      )
                                    : '--',
                                unit: hasRuns ? 'km' : null,
                                highlight: hasRuns,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: NearPaceSpacing.xs),
                            Expanded(
                              child: MetricTile(
                                label: 'Best pace',
                                value: NearPaceFormatters.paceValue(bestPace),
                                unit: bestPace == null ? null : '/km',
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: NearPaceSpacing.xs),
                            Expanded(
                              child: MetricTile(
                                label: 'Total time',
                                value: hasRuns
                                    ? NearPaceFormatters.durationCompact(
                                        controller.totalDuration,
                                      )
                                    : '--',
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.lg),

                      // Notifications & Run Reminders.
                      Text('Notifications', style: textTheme.titleMedium),
                      const SizedBox(height: NearPaceSpacing.xs),
                      NearPaceCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: NearPaceSpacing.md,
                          vertical: NearPaceSpacing.xs,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Run reminders',
                                style: textTheme.titleSmall,
                              ),
                              subtitle: Text(
                                reminder.enabled
                                    ? (nextReminderLabel != null
                                          ? 'Next reminder: $nextReminderLabel'
                                          : 'Pick at least one day below.')
                                    : 'Get scheduled nudges on your running days.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: reminder.isActive
                                      ? colors.accentText
                                      : colors.textSecondary,
                                ),
                              ),
                              value: reminder.enabled,
                              onChanged: (enabled) async {
                                final nextDays =
                                    enabled && reminder.weekdays.isEmpty
                                    ? RunReminder.defaultWeekdays
                                    : reminder.weekdays;
                                await controller.updateRunReminder(
                                  reminder.copyWith(
                                    enabled: enabled,
                                    weekdays: nextDays,
                                  ),
                                );
                              },
                            ),
                            if (reminder.enabled) ...[
                              Divider(color: colors.border),
                              const SizedBox(height: NearPaceSpacing.xs),
                              Text(
                                'Repeat days',
                                style: textTheme.labelMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: NearPaceSpacing.xs),
                              Wrap(
                                spacing: NearPaceSpacing.xs,
                                runSpacing: NearPaceSpacing.xs,
                                children: List.generate(7, (index) {
                                  final weekday = index + 1;
                                  final selected = reminder.weekdays.contains(
                                    weekday,
                                  );
                                  return _WeekdayChip(
                                    weekday: weekday,
                                    selected: selected,
                                    onTap: () =>
                                        _toggleWeekday(controller, weekday),
                                  );
                                }),
                              ),
                              const SizedBox(height: NearPaceSpacing.sm),
                              InkWell(
                                borderRadius: BorderRadius.circular(
                                  NearPaceSpacing.radiusSm,
                                ),
                                onTap: () =>
                                    _pickReminderTime(context, controller),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: NearPaceSpacing.xs,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 20,
                                        color: colors.textSecondary,
                                      ),
                                      const SizedBox(width: NearPaceSpacing.xs),
                                      Expanded(
                                        child: Text(
                                          'Reminder time',
                                          style: textTheme.titleSmall,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: NearPaceSpacing.sm,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.deepGreenSurface,
                                          borderRadius: BorderRadius.circular(
                                            NearPaceSpacing.radiusPill,
                                          ),
                                          border: Border.all(
                                            color: colors.accentText.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          reminder.formattedTime,
                                          style: textTheme.labelLarge?.copyWith(
                                            color: colors.accentText,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: colors.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: NearPaceSpacing.xs),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await controller.sendTestReminder();
                                    if (!context.mounted ||
                                        controller.isLocalPreview) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Test reminder sent!'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.notifications_active_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Send test reminder'),
                                ),
                              ),
                              const SizedBox(height: NearPaceSpacing.xs),
                            ],
                            Divider(color: colors.border),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Weekly updates',
                                style: textTheme.titleSmall,
                              ),
                              subtitle: Text(
                                'Leaderboard resets and weekly run highlights.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              value: profile.receiveUpdates,
                              onChanged: (value) async {
                                try {
                                  await controller.setReceiveUpdates(value);
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to update notification '
                                        'preferences: $e',
                                      ),
                                    ),
                                  );
                                }
                              },
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
                      const SizedBox(height: NearPaceSpacing.md),
                      Center(
                        child: Text(
                          'NearPace v1.0.0',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
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

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.weekday,
    required this.selected,
    required this.onTap,
  });

  final int weekday;
  final bool selected;
  final VoidCallback onTap;

  static const _fullNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final letter = NearPaceFormatters.weekdayInitial(weekday);
    final name = _fullNames[(weekday - 1).clamp(0, 6)];

    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: Material(
        color: selected ? colors.accent : colors.surfaceElevated,
        shape: CircleBorder(
          side: BorderSide(color: selected ? colors.accent : colors.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  letter,
                  maxLines: 1,
                  style: textTheme.labelMedium?.copyWith(
                    color: selected ? colors.onAccent : colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
    final colors = context.npColors;
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
                'when you join.',
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
              InkWell(
                onTap: () async {
                  final selected = await CityPickerSheet.show(
                    context,
                    currentCity: _cityController.text.isNotEmpty
                        ? _cityController.text
                        : null,
                    title: 'Select City in Indonesia',
                  );
                  if (selected != null) {
                    setState(() {
                      _cityController.text = selected;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'City (optional)',
                    hintText: 'Select Indonesian city...',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_cityController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _cityController.clear();
                              });
                            },
                          ),
                        const Icon(Icons.location_city_rounded),
                        const SizedBox(width: NearPaceSpacing.xs),
                      ],
                    ),
                  ),
                  child: Text(
                    _cityController.text.isNotEmpty
                        ? _cityController.text
                        : 'Select your city (GPS auto-detect)',
                    style: _cityController.text.isNotEmpty
                        ? textTheme.bodyLarge
                        : textTheme.bodyLarge?.copyWith(
                            color: colors.textMuted,
                          ),
                  ),
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
