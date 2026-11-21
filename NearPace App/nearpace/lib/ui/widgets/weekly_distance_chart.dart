import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';

/// Compact Mon–Sun capsule bar chart showing daily distance totals for the
/// current ISO week.
class WeeklyDistanceChart extends StatelessWidget {
  const WeeklyDistanceChart({
    super.key,
    required this.dailyDistancesMeters,
    required this.todayWeekday,
  });

  /// Length-7 list (index 0 = Monday .. index 6 = Sunday).
  final List<double> dailyDistancesMeters;

  /// Current weekday (1 = Monday .. 7 = Sunday).
  final int todayWeekday;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final maxMeters = dailyDistancesMeters.fold<double>(
      0,
      (prev, value) => math.max(prev, value),
    );
    final scaleMax = math.max(maxMeters, 1000.0);
    final duration = NearPaceMotion.resolve(context, NearPaceMotion.standard);

    return Semantics(
      label: 'Weekly distance breakdown from Monday to Sunday',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final meters = index < dailyDistancesMeters.length
              ? dailyDistancesMeters[index]
              : 0.0;
          final ratio = meters <= 0
              ? 0.0
              : (meters / scaleMax).clamp(0.14, 1.0);
          final isToday = index + 1 == todayWeekday;
          final hasRun = meters > 0;
          final label = NearPaceFormatters.weekdayInitial(index + 1);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 16,
                    child: hasRun
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              NearPaceFormatters.distanceKmValue(
                                meters,
                                decimals: 1,
                              ),
                              style: textTheme.bodySmall?.copyWith(
                                color: isToday
                                    ? colors.accentText
                                    : colors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 68,
                    width: double.infinity,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isToday
                            ? colors.accentText.withValues(alpha: 0.45)
                            : colors.border,
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: AnimatedFractionallySizedBox(
                      duration: duration,
                      curve: NearPaceMotion.easeOut,
                      heightFactor: ratio,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: hasRun
                              ? (isToday
                                    ? colors.accent
                                    : colors.performanceGreen)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: isToday ? colors.accentText : colors.textMuted,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
