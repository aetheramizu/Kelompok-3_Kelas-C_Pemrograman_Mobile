import 'package:material_ui/material_ui.dart';

/// Semantic color tokens for NearPace across dark and light appearances.
///
/// Built around a deep graphite + electric lime identity refined for WCAG AA
/// contrast (>= 4.5:1 for normal text, >= 3:1 for non-text UI elements).
@immutable
class NearPaceColors extends ThemeExtension<NearPaceColors> {
  const NearPaceColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.performanceGreen,
    required this.deepGreenSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.warning,
    required this.warningSurface,
    required this.danger,
    required this.dangerSurface,
    required this.routeGrid,
  });

  /// Main app scaffold canvas.
  final Color background;

  /// Primary cards and navigation surfaces.
  final Color surface;

  /// Elevated cards, dialogs, bottom sheets, and input fills.
  final Color surfaceElevated;

  /// Hairline outlines, dividers, and card borders.
  final Color border;

  /// Primary CTA fill, active indicator, and route polyline highlight.
  final Color accent;

  /// High-contrast ink placed on top of [accent].
  final Color onAccent;

  /// Accent color safe for small text and icons directly on [surface].
  final Color accentText;

  /// Positive trends, active GPS lock, and progress fills.
  final Color performanceGreen;

  /// Subtle green-tinted surface for secondary highlights and badges.
  final Color deepGreenSurface;

  /// Headings, hero metrics, and primary body copy.
  final Color textPrimary;

  /// Descriptions, labels, and supporting details.
  final Color textSecondary;

  /// Tertiary metadata (kept >= 4.5:1 on primary surfaces).
  final Color textMuted;

  /// Paused state, weak GPS, and caution notices.
  final Color warning;

  /// Tinted container behind warning badges.
  final Color warningSurface;

  /// Destructive actions, errors, and permission denied states.
  final Color danger;

  /// Tinted container behind error banners.
  final Color dangerSurface;

  /// Subtle grid lines behind CustomPainter route sketches.
  final Color routeGrid;

  static const NearPaceColors dark = NearPaceColors(
    background: Color(0xFF131614),
    surface: Color(0xFF1C211E),
    surfaceElevated: Color(0xFF252C28),
    border: Color(0xFF323B35),
    accent: Color(0xFFB7F36B),
    onAccent: Color(0xFF111612),
    accentText: Color(0xFFB7F36B),
    performanceGreen: Color(0xFF4ADE80),
    deepGreenSurface: Color(0xFF1E3B29),
    textPrimary: Color(0xFFF2F5F0),
    textSecondary: Color(0xFFA8B3AA),
    textMuted: Color(0xFF87948A),
    warning: Color(0xFFFBBF24),
    warningSurface: Color(0xFF332A14),
    danger: Color(0xFFF87171),
    dangerSurface: Color(0xFF381D1E),
    routeGrid: Color(0xFF28302B),
  );

  static const NearPaceColors light = NearPaceColors(
    background: Color(0xFFF4F6F3),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEAEFE8),
    border: Color(0xFFD2DBD0),
    accent: Color(0xFFB7F36B),
    onAccent: Color(0xFF111612),
    accentText: Color(0xFF215A2C),
    performanceGreen: Color(0xFF15803D),
    deepGreenSurface: Color(0xFFE1F2E5),
    textPrimary: Color(0xFF141915),
    textSecondary: Color(0xFF48544B),
    textMuted: Color(0xFF5D6A60),
    warning: Color(0xFFB45309),
    warningSurface: Color(0xFFFEF3C7),
    danger: Color(0xFFDC2626),
    dangerSurface: Color(0xFFFEE2E2),
    routeGrid: Color(0xFFE1E8DF),
  );

  @override
  NearPaceColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? accent,
    Color? onAccent,
    Color? accentText,
    Color? performanceGreen,
    Color? deepGreenSurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? warning,
    Color? warningSurface,
    Color? danger,
    Color? dangerSurface,
    Color? routeGrid,
  }) {
    return NearPaceColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentText: accentText ?? this.accentText,
      performanceGreen: performanceGreen ?? this.performanceGreen,
      deepGreenSurface: deepGreenSurface ?? this.deepGreenSurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      routeGrid: routeGrid ?? this.routeGrid,
    );
  }

  @override
  NearPaceColors lerp(ThemeExtension<NearPaceColors>? other, double t) {
    if (other is! NearPaceColors) return this;
    return NearPaceColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      performanceGreen: Color.lerp(
        performanceGreen,
        other.performanceGreen,
        t,
      )!,
      deepGreenSurface: Color.lerp(
        deepGreenSurface,
        other.deepGreenSurface,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      routeGrid: Color.lerp(routeGrid, other.routeGrid, t)!,
    );
  }
}

extension NearPaceThemeContext on BuildContext {
  NearPaceColors get npColors =>
      Theme.of(this).extension<NearPaceColors>() ?? NearPaceColors.dark;
}
