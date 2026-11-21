import 'package:material_ui/material_ui.dart';

import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';

/// Displays a single tabular running metric (value + optional unit + label).
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.highlight = false,
    this.compact = false,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final bool highlight;
  final bool compact;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final valueStyle =
        (compact ? textTheme.titleLarge : textTheme.headlineMedium)?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          color: highlight ? colors.accentText : colors.textPrimary,
          fontWeight: FontWeight.w700,
        );

    return Semantics(
      label: '$label: $value${unit == null ? '' : ' $unit'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: 14,
                    color: highlight ? colors.accentText : colors.textMuted,
                  ),
                ),
                const SizedBox(width: NearPaceSpacing.xxs),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NearPaceSpacing.xxs),
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
