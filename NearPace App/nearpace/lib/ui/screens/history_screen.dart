import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/activity.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/activity_card.dart';
import '../widgets/metric_tile.dart';
import '../widgets/nearpace_card.dart';
import '../widgets/state_views.dart';
import 'record_run_screen.dart';
import 'run_result_screen.dart';

enum _HistoryFilter { all, thisWeek, fiveKmPlus }

/// Lists the runner's saved runs newest-first with cumulative metrics and
/// explicit empty, loading, and error states.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  List<Activity> _applyFilter(List<Activity> all, String currentWeekKey) {
    final sorted = List<Activity>.from(all)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return switch (_filter) {
      _HistoryFilter.all => sorted,
      _HistoryFilter.thisWeek =>
        sorted
            .where(
              (a) =>
                  NearPaceFormatters.isoWeekKey(a.startedAt) == currentWeekKey,
            )
            .toList(growable: false),
      _HistoryFilter.fiveKmPlus =>
        sorted.where((a) => a.distanceM >= 5000).toList(growable: false),
    };
  }

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
    final allRuns = controller.activities;
    final filteredRuns = _applyFilter(allRuns, controller.currentWeekKey);
    final totalDuration = Duration(
      seconds: allRuns.fold(0, (sum, a) => sum + a.durationS),
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
                key: const ValueKey('history-scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      NearPaceSpacing.md,
                      gutter,
                      NearPaceSpacing.sm,
                    ),
                    sliver: SliverList.list(
                      children: [
                        Text('History', style: textTheme.headlineMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Private saved runs, newest first',
                          style: textTheme.bodyMedium,
                        ),
                        if (controller.pendingSyncCount > 0) ...[
                          const SizedBox(height: NearPaceSpacing.sm),
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
                        ],
                        const SizedBox(height: NearPaceSpacing.md),

                        // Cumulative summary bar.
                        NearPaceCard(
                          padding: const EdgeInsets.all(NearPaceSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: MetricTile(
                                  label: 'Runs',
                                  value: '${allRuns.length}',
                                  compact: true,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: colors.border,
                              ),
                              const SizedBox(width: NearPaceSpacing.md),
                              Expanded(
                                child: MetricTile(
                                  label: 'Distance',
                                  value: NearPaceFormatters.distanceKmValue(
                                    controller.totalDistanceMeters,
                                    decimals: 1,
                                  ),
                                  unit: 'km',
                                  highlight: true,
                                  compact: true,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: colors.border,
                              ),
                              const SizedBox(width: NearPaceSpacing.md),
                              Expanded(
                                child: MetricTile(
                                  label: 'Total time',
                                  value: NearPaceFormatters.durationCompact(
                                    totalDuration,
                                  ),
                                  compact: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: NearPaceSpacing.md),

                        // Filter chips.
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChipItem(
                                label: 'All runs',
                                selected: _filter == _HistoryFilter.all,
                                onSelected: () => setState(
                                  () => _filter = _HistoryFilter.all,
                                ),
                              ),
                              const SizedBox(width: NearPaceSpacing.xs),
                              _FilterChipItem(
                                label: 'This week',
                                selected: _filter == _HistoryFilter.thisWeek,
                                onSelected: () => setState(
                                  () => _filter = _HistoryFilter.thisWeek,
                                ),
                              ),
                              const SizedBox(width: NearPaceSpacing.xs),
                              _FilterChipItem(
                                label: '5 km+',
                                selected: _filter == _HistoryFilter.fiveKmPlus,
                                onSelected: () => setState(
                                  () => _filter = _HistoryFilter.fiveKmPlus,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main history content states.
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      NearPaceSpacing.xs,
                      gutter,
                      NearPaceSpacing.xxxl,
                    ),
                    sliver: switch (controller.historyState) {
                      ViewLoadState.loading => const SliverToBoxAdapter(
                        child: LoadingSkeletonList(itemCount: 4),
                      ),
                      ViewLoadState.error => SliverToBoxAdapter(
                        child: ErrorStateView(
                          title: 'Could not load activity history',
                          message:
                              controller.historyError ??
                              'Check your connection and try again.',
                          onRetry: controller.retryHistory,
                        ),
                      ),
                      ViewLoadState.ready when allRuns.isEmpty =>
                        SliverToBoxAdapter(
                          child: EmptyStateView(
                            icon: Icons.history_rounded,
                            title: 'No saved runs yet',
                            message:
                                'Finished runs you save will appear here with '
                                'their route sketch, pace, and weather.',
                            actionLabel: 'Start a run',
                            onAction: () => _openRecorder(context),
                          ),
                        ),
                      ViewLoadState.ready when filteredRuns.isEmpty =>
                        SliverToBoxAdapter(
                          child: EmptyStateView(
                            icon: Icons.filter_list_off_rounded,
                            title: 'No runs match this filter',
                            message:
                                'Try switching back to All runs to see your full '
                                'history.',
                            actionLabel: 'Show all runs',
                            onAction: () =>
                                setState(() => _filter = _HistoryFilter.all),
                          ),
                        ),
                      ViewLoadState.ready => SliverList.separated(
                        itemCount: filteredRuns.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: NearPaceSpacing.sm),
                        itemBuilder: (context, index) {
                          final activity = filteredRuns[index];
                          return ActivityCard(
                            key: ValueKey(activity.id),
                            activity: activity,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      RunResultScreen(activity: activity),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    },
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

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? colors.onAccent : colors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        fontSize: 13,
      ),
      selectedColor: colors.accent,
      backgroundColor: colors.surface,
      side: BorderSide(color: selected ? colors.accent : colors.border),
      onSelected: (_) => onSelected(),
    );
  }
}
