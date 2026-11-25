import 'package:material_ui/material_ui.dart';

import '../../domain/activity.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import 'nearpace_card.dart';
import 'route_sketch.dart';
import 'share_activity_sheet.dart';
import 'weather_badge.dart';

/// Reusable run summary row displayed on Home and History screens.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity, required this.onTap});

  final Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final title = NearPaceFormatters.runSessionTitle(activity.startedAt);
    final timestamp = NearPaceFormatters.activityTimestamp(activity.startedAt);
    final distance = NearPaceFormatters.distanceKm(activity.distanceM);
    final duration = NearPaceFormatters.durationClock(activity.duration);
    final pace = NearPaceFormatters.paceWithUnit(activity.avgPaceSecPerKm);

    return NearPaceCard(
      onTap: onTap,
      semanticLabel: '$title on $timestamp, $distance, $duration, pace $pace',
      padding: const EdgeInsets.all(NearPaceSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: RouteSketch(
              route: activity.route,
              height: 72,
              compact: true,
              showEndpoints: false,
              showGrid: false,
            ),
          ),
          const SizedBox(width: NearPaceSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: NearPaceSpacing.xs),
                    if (activity.pendingSync) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.warningSurface,
                          borderRadius: BorderRadius.circular(
                            NearPaceSpacing.radiusPill,
                          ),
                          border: Border.all(
                            color: colors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 11,
                              color: colors.warning,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Pending sync',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: NearPaceSpacing.xs),
                    ],
                    WeatherPill(weather: activity.weather),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  timestamp,
                  style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: NearPaceSpacing.xs),
                Wrap(
                  spacing: NearPaceSpacing.md,
                  runSpacing: NearPaceSpacing.xxs,
                  children: [
                    _InlineMetric(value: distance, emphasize: true),
                    _InlineMetric(value: duration),
                    _InlineMetric(value: pace),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: NearPaceSpacing.xxs),
          IconButton(
            tooltip: 'Share run',
            icon: Icon(Icons.share_outlined, color: colors.textMuted, size: 18),
            onPressed: () =>
                ShareActivitySheet.show(context, activity: activity),
          ),
          ExcludeSemantics(
            child: Icon(
              Icons.chevron_right_rounded,
              color: colors.textMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.value, this.emphasize = false});

  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    return Text(
      value,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: emphasize ? colors.textPrimary : colors.textSecondary,
        fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
