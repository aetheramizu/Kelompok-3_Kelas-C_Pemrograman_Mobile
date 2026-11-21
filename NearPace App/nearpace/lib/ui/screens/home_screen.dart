import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../config/firebase_bootstrap.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/activity_card.dart';
import '../widgets/metric_tile.dart';
import '../widgets/nearpace_card.dart';
import '../widgets/state_views.dart';
import '../widgets/weekly_distance_chart.dart';
import 'record_run_screen.dart';
import 'run_result_screen.dart';

/// Main runner dashboard displaying this week's running volume, a direct start
/// CTA, and the runner's most recent saved activities.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openRecorder(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const RecordRunScreen(),
      ),
    );
  }

  void _showBackendStatusSheet(
    BuildContext context,
    FirebaseBootstrapStatus status,
  ) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final (title, detail) = switch (status) {
      FirebaseReady() => (
        'Firebase Core initialized',
        'Firebase build-time options are present. Backend auth, Firestore, '
            'and FCM integration can connect here.',
      ),
      FirebaseUnconfigured(:final missingKeys) => (
        'Local preview mode',
        missingKeys.isEmpty
            ? 'Firebase options were not supplied at build time. Runs and '
                  'profile edits remain local to this session.'
            : 'Firebase options are not configured (missing: '
                  '${missingKeys.join(', ')}). Runs and profile edits remain '
                  'local to this preview session.',
      ),
      FirebaseInitFailed(:final message) => (
        'Firebase initialization failed',
        'NearPace fell back to local preview mode. Error: $message',
      ),
    };

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
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
              Row(
                children: [
                  Icon(
                    status is FirebaseReady
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    color: status is FirebaseReady
                        ? colors.performanceGreen
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: NearPaceSpacing.xs),
                  Expanded(child: Text(title, style: textTheme.titleLarge)),
                ],
              ),
              const SizedBox(height: NearPaceSpacing.sm),
              Text(detail, style: textTheme.bodyMedium),
              const SizedBox(height: NearPaceSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final profile = controller.profile;
    final firstName = profile.displayName.trim().split(RegExp(r'\s+')).first;
    final recentRuns = controller.activities.take(3).toList(growable: false);

    final (
      statusLabel,
      statusIcon,
      statusFg,
      statusBg,
    ) = switch (controller.firebaseStatus) {
      FirebaseReady() => (
        'Firebase ready',
        Icons.cloud_done_outlined,
        colors.performanceGreen,
        colors.deepGreenSurface,
      ),
      FirebaseUnconfigured() => (
        'Local preview',
        Icons.offline_bolt_outlined,
        colors.textSecondary,
        colors.surfaceElevated,
      ),
      FirebaseInitFailed() => (
        'Firebase error',
        Icons.warning_amber_rounded,
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
                      // Greeting row + avatar shortcut to Profile.
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  NearPaceFormatters.shortHeaderDate(
                                    controller.now,
                                  ).toUpperCase(),
                                  style: textTheme.labelSmall?.copyWith(
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ready, $firstName?',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.headlineMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: NearPaceSpacing.xs),
                          StatusPill(
                            label: statusLabel,
                            icon: statusIcon,
                            foregroundColor: statusFg,
                            backgroundColor: statusBg,
                            onTap: () => _showBackendStatusSheet(
                              context,
                              controller.firebaseStatus,
                            ),
                          ),
                          const SizedBox(width: NearPaceSpacing.xs),
                          Semantics(
                            button: true,
                            label: 'Open profile',
                            child: InkWell(
                              onTap: () => controller.setTabIndex(3),
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colors.deepGreenSurface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.accentText.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  profile.initials,
                                  style: textTheme.titleSmall?.copyWith(
                                    color: colors.accentText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NearPaceSpacing.lg),

                      // This Week Summary Card.
                      NearPaceCard(
                        padding: const EdgeInsets.all(NearPaceSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'THIS WEEK',
                                        style: textTheme.labelSmall?.copyWith(
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        NearPaceFormatters.weekRangeLabel(
                                          controller.now,
                                        ),
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusPill(
                                  label:
                                      '${controller.weeklyActivities.length} '
                                      '${controller.weeklyActivities.length == 1 ? 'run' : 'runs'}',
                                  foregroundColor: colors.accentText,
                                  backgroundColor: colors.deepGreenSurface,
                                  borderColor: colors.performanceGreen
                                      .withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                            const SizedBox(height: NearPaceSpacing.md),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  NearPaceFormatters.distanceKmValue(
                                    controller.weeklyDistanceMeters,
                                  ),
                                  style: textTheme.displayMedium?.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'km',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: colors.accentText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: NearPaceSpacing.md),
                            WeeklyDistanceChart(
                              dailyDistancesMeters:
                                  controller.weeklyDailyDistancesMeters,
                              todayWeekday: controller.now.weekday,
                            ),
                            const SizedBox(height: NearPaceSpacing.md),
                            Divider(color: colors.border),
                            const SizedBox(height: NearPaceSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: MetricTile(
                                    label: 'Time',
                                    value: NearPaceFormatters.durationCompact(
                                      controller.weeklyDuration,
                                    ),
                                    compact: true,
                                  ),
                                ),
                                Expanded(
                                  child: MetricTile(
                                    label: 'Avg pace',
                                    value: NearPaceFormatters.paceValue(
                                      controller.weeklyAvgPaceSecPerKm,
                                    ),
                                    unit: '/km',
                                    compact: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.md),

                      // Primary Quick-Start Run Card.
                      NearPaceCard(
                        backgroundColor: colors.accent,
                        borderColor: colors.accent,
                        onTap: () => _openRecorder(context),
                        semanticLabel: 'Start a new outdoor run',
                        padding: const EdgeInsets.symmetric(
                          horizontal: NearPaceSpacing.lg,
                          vertical: NearPaceSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'QUICK START',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colors.onAccent.withValues(
                                        alpha: 0.72,
                                      ),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Start a run',
                                    style: textTheme.headlineMedium?.copyWith(
                                      color: colors.onAccent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Foreground GPS distance, pace & route sketch',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.onAccent.withValues(
                                        alpha: 0.78,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: NearPaceSpacing.sm),
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: colors.onAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: 30,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.xl),

                      // Recent Activities Section.
                      SectionHeader(
                        title: 'Recent runs',
                        trailingLabel: recentRuns.isEmpty ? null : 'See all',
                        onTrailingTap: recentRuns.isEmpty
                            ? null
                            : () => controller.setTabIndex(1),
                      ),
                      const SizedBox(height: NearPaceSpacing.xs),
                      switch (controller.historyState) {
                        ViewLoadState.loading => const LoadingSkeletonList(
                          itemCount: 3,
                        ),
                        ViewLoadState.error => ErrorStateView(
                          title: 'Could not load recent runs',
                          message:
                              controller.historyError ??
                              'Unable to load your saved activities right now.',
                          onRetry: controller.retryHistory,
                        ),
                        ViewLoadState.ready when recentRuns.isEmpty =>
                          EmptyStateView(
                            icon: Icons.directions_run_rounded,
                            title: 'No runs recorded yet',
                            message:
                                'Start an outdoor run to log your distance, '
                                'average pace, and route sketch.',
                            actionLabel: 'Start first run',
                            onAction: () => _openRecorder(context),
                          ),
                        ViewLoadState.ready => Column(
                          children: List.generate(recentRuns.length, (index) {
                            final activity = recentRuns[index];
                            return Padding(
                              key: ValueKey(activity.id),
                              padding: EdgeInsets.only(
                                bottom: index == recentRuns.length - 1
                                    ? 0
                                    : NearPaceSpacing.sm,
                              ),
                              child: ActivityCard(
                                activity: activity,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          RunResultScreen(activity: activity),
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                        ),
                      },
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
