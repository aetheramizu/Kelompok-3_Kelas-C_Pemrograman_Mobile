import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/activity.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/metric_tile.dart';
import '../widgets/nearpace_card.dart';
import '../widgets/route_sketch.dart';
import '../widgets/state_views.dart';
import '../widgets/weather_badge.dart';

/// Displays a completed or saved run with metrics, route sketch, and start-point
/// weather summary.
class RunResultScreen extends StatelessWidget {
  const RunResultScreen({
    super.key,
    required this.activity,
    this.isUnsaved = false,
  });

  final Activity activity;
  final bool isUnsaved;

  Future<void> _confirmDiscard(BuildContext context) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this run?'),
        content: const Text(
          'This recorded run has not been saved yet. Discarding removes its '
          'distance and route sketch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.npColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && context.mounted) {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _confirmDeleteSaved(BuildContext context) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove run from history?'),
        content: const Text(
          'This removes the run from your local preview history and updates '
          'this week\'s totals.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (delete == true && context.mounted) {
      context.read<NearPaceController>().deleteActivity(activity.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run removed from preview history.')),
      );
      Navigator.of(context).pop();
    }
  }

  void _saveRun(BuildContext context) {
    final controller = context.read<NearPaceController>();
    controller.saveActivity(activity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          controller.isLocalPreview
              ? 'Run saved to local preview history.'
              : 'Run saved to your history.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final title = NearPaceFormatters.runSessionTitle(activity.startedAt);
    final timestamp = NearPaceFormatters.activityTimestamp(activity.startedAt);
    final endedHh = activity.endedAt.toLocal().hour.toString().padLeft(2, '0');
    final endedMm = activity.endedAt.toLocal().minute.toString().padLeft(
      2,
      '0',
    );

    return PopScope(
      canPop: !isUnsaved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isUnsaved) {
          _confirmDiscard(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isUnsaved ? 'Run summary' : 'Activity detail'),
          leading: IconButton(
            tooltip: isUnsaved ? 'Discard run' : 'Back',
            onPressed: () {
              if (isUnsaved) {
                _confirmDiscard(context);
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: Icon(
              isUnsaved ? Icons.close_rounded : Icons.arrow_back_rounded,
            ),
          ),
          actions: [
            if (!isUnsaved)
              IconButton(
                tooltip: 'Remove run',
                onPressed: () => _confirmDeleteSaved(context),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = NearPaceSpacing.pageGutter(constraints.maxWidth);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: NearPaceSpacing.maxContentWidth,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          NearPaceSpacing.sm,
                          gutter,
                          NearPaceSpacing.xl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hero Route Sketch with header metadata.
                            Stack(
                              children: [
                                RouteSketch(
                                  route: activity.route,
                                  height: 220,
                                  emptyMessage:
                                      'Route too short to sketch (fewer than '
                                      '2 GPS points recorded)',
                                ),
                                Positioned(
                                  left: NearPaceSpacing.sm,
                                  top: NearPaceSpacing.sm,
                                  child: StatusPill(
                                    label: activity.hasRoute
                                        ? '${activity.route.length} GPS points'
                                        : 'No GPS trace',
                                    icon: Icons.route_rounded,
                                    backgroundColor: colors.surface.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: NearPaceSpacing.lg),

                            // Title + Hero Distance.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: textTheme.titleLarge),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$timestamp – $endedHh:$endedMm',
                                        style: textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isUnsaved)
                                  StatusPill(
                                    label: 'Unsaved',
                                    foregroundColor: colors.warning,
                                    backgroundColor: colors.warningSurface,
                                    borderColor: colors.warning.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: NearPaceSpacing.lg),

                            // Primary Metrics Grid (Distance, Duration, Pace, Window).
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: NearPaceSpacing.sm,
                              crossAxisSpacing: NearPaceSpacing.sm,
                              childAspectRatio: 1.55,
                              children: [
                                NearPaceCard(
                                  padding: const EdgeInsets.all(
                                    NearPaceSpacing.md,
                                  ),
                                  child: MetricTile(
                                    label: 'Distance',
                                    value: NearPaceFormatters.distanceKmValue(
                                      activity.distanceM,
                                    ),
                                    unit: 'km',
                                    icon: Icons.straighten_rounded,
                                    highlight: true,
                                  ),
                                ),
                                NearPaceCard(
                                  padding: const EdgeInsets.all(
                                    NearPaceSpacing.md,
                                  ),
                                  child: MetricTile(
                                    label: 'Duration',
                                    value: NearPaceFormatters.durationClock(
                                      activity.duration,
                                    ),
                                    icon: Icons.timer_outlined,
                                  ),
                                ),
                                NearPaceCard(
                                  padding: const EdgeInsets.all(
                                    NearPaceSpacing.md,
                                  ),
                                  child: MetricTile(
                                    label: 'Avg pace',
                                    value: NearPaceFormatters.paceValue(
                                      activity.avgPaceSecPerKm,
                                    ),
                                    unit: '/km',
                                    icon: Icons.speed_rounded,
                                  ),
                                ),
                                NearPaceCard(
                                  padding: const EdgeInsets.all(
                                    NearPaceSpacing.md,
                                  ),
                                  child: MetricTile(
                                    label: 'GPS points',
                                    value: '${activity.route.length}',
                                    unit: 'pts',
                                    icon: Icons.gps_fixed_rounded,
                                  ),
                                ),
                              ],
                            ),

                            if (activity.avgPaceSecPerKm == null) ...[
                              const SizedBox(height: NearPaceSpacing.sm),
                              Text(
                                'Average pace requires at least 50 m of '
                                'recorded distance.',
                                style: textTheme.bodySmall,
                              ),
                            ],

                            const SizedBox(height: NearPaceSpacing.lg),
                            Text(
                              'Start-point weather',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: NearPaceSpacing.xs),
                            WeatherSummaryCard(weather: activity.weather),
                          ],
                        ),
                      ),
                    ),
                    if (isUnsaved)
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            gutter,
                            NearPaceSpacing.sm,
                            gutter,
                            NearPaceSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border(
                              top: BorderSide(color: colors.border),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Saved locally in preview mode. Cloud sync '
                                'activates once Firebase is configured.',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall,
                              ),
                              const SizedBox(height: NearPaceSpacing.sm),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => _saveRun(context),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Save run'),
                                ),
                              ),
                              const SizedBox(height: NearPaceSpacing.xs),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () => _confirmDiscard(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: colors.danger,
                                  ),
                                  child: const Text('Discard run'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
