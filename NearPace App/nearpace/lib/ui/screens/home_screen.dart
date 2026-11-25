import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/activity_card.dart';
import '../widgets/metric_tile.dart';
import '../widgets/nearpace_avatar.dart';
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final profile = controller.profile;
    final firstName = profile.displayName.trim().split(RegExp(r'\s+')).first;
    final recentRuns = controller.activities.take(3).toList(growable: false);
    final nextReminderLabel = profile.runReminder.nextSummaryLabel(
      controller.now,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = NearPaceSpacing.pageGutter(constraints.maxWidth);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: NearPaceSpacing.maxContentWidth,
            ),
            child: RefreshIndicator(
              onRefresh: () => controller.syncPendingActivities(force: true),
              child: CustomScrollView(
                key: const ValueKey('home-scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
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
                        if (controller.pendingSyncCount > 0) ...[
                          NearPaceCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: NearPaceSpacing.sm,
                              vertical: NearPaceSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 18,
                                  color: colors.warning,
                                ),
                                const SizedBox(width: NearPaceSpacing.xs),
                                Expanded(
                                  child: Text(
                                    '${controller.pendingSyncCount} ${controller.pendingSyncCount == 1 ? 'run' : 'runs'} waiting to sync',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.warning,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: controller.isSyncingActivities
                                      ? null
                                      : () => controller.syncPendingActivities(
                                          force: true,
                                        ),
                                  child: controller.isSyncingActivities
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Sync now'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: NearPaceSpacing.sm),
                        ],
                        // Greeting row + avatar shortcut to Profile.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                            const SizedBox(width: NearPaceSpacing.sm),
                            Semantics(
                              button: true,
                              label: 'Open profile',
                              child: NearPaceAvatar(
                                avatarId: profile.avatarId,
                                name: profile.displayName,
                                size: NearPaceSpacing.minTapTarget,
                                onTap: () => controller.setTabIndex(3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: NearPaceSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: StatusPill(
                            label: nextReminderLabel != null
                                ? 'Next run · $nextReminderLabel'
                                : 'Set a run reminder',
                            icon: nextReminderLabel != null
                                ? Icons.notifications_active_outlined
                                : Icons.alarm_add_rounded,
                            foregroundColor: nextReminderLabel != null
                                ? colors.accentText
                                : colors.textSecondary,
                            backgroundColor: nextReminderLabel != null
                                ? colors.deepGreenSurface
                                : colors.surfaceElevated,
                            onTap: () => controller.setTabIndex(3),
                          ),
                        ),
                        const SizedBox(height: NearPaceSpacing.md),

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
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
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
                            message: controller.historyError ?? 'Unable to load your saved activities right now.',
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
          ),
        );
      },
    );
  }
}
