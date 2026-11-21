import 'package:material_ui/material_ui.dart';

import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';

/// Foundational NearPace card container with crisp hairline border and
/// optional accessible tap feedback.
class NearPaceCard extends StatelessWidget {
  const NearPaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NearPaceSpacing.md),
    this.elevated = false,
    this.borderColor,
    this.backgroundColor,
    this.borderRadius = NearPaceSpacing.radiusLg,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  final Color? borderColor;
  final Color? backgroundColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final fill =
        backgroundColor ?? (elevated ? colors.surfaceElevated : colors.surface);
    final outline = borderColor ?? colors.border;
    final radius = BorderRadius.circular(borderRadius);

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: colors.accent.withValues(alpha: 0.12),
        highlightColor: colors.accent.withValues(alpha: 0.06),
        child: content,
      );
    }

    final card = Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (semanticLabel != null) {
      return Semantics(
        button: onTap != null,
        label: semanticLabel,
        child: card,
      );
    }
    return card;
  }
}
