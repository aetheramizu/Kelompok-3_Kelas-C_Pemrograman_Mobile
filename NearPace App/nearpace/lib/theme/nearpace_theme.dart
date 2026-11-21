import 'package:material_ui/material_ui.dart';

import 'nearpace_colors.dart';
import 'nearpace_spacing.dart';

/// Builds NearPace's dark and light Material 3 themes from [NearPaceColors].
class NearPaceTheme {
  const NearPaceTheme._();

  static ThemeData dark() =>
      _build(brightness: Brightness.dark, colors: NearPaceColors.dark);

  static ThemeData light() =>
      _build(brightness: Brightness.light, colors: NearPaceColors.light);

  static ThemeData _build({
    required Brightness brightness,
    required NearPaceColors colors,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      primaryContainer: colors.deepGreenSurface,
      onPrimaryContainer: colors.textPrimary,
      secondary: colors.performanceGreen,
      onSecondary: colors.onAccent,
      secondaryContainer: colors.surfaceElevated,
      onSecondaryContainer: colors.textPrimary,
      tertiary: colors.accentText,
      onTertiary: colors.onAccent,
      error: colors.danger,
      onError: isDark ? const Color(0xFF1A0A0A) : Colors.white,
      errorContainer: colors.dangerSurface,
      onErrorContainer: colors.danger,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceElevated,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
      outlineVariant: colors.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: colors.textPrimary,
      onInverseSurface: colors.background,
      inversePrimary: colors.accentText,
    );

    const tabular = [FontFeature.tabularFigures()];

    final baseText = (isDark ? ThemeData.dark() : ThemeData.light()).textTheme;

    final textTheme = baseText.copyWith(
      displayLarge: TextStyle(
        fontSize: 52,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.04,
        color: colors.textPrimary,
        fontFeatures: tabular,
      ),
      displayMedium: TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.08,
        color: colors.textPrimary,
        fontFeatures: tabular,
      ),
      displaySmall: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.12,
        color: colors.textPrimary,
        fontFeatures: tabular,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.2,
        color: colors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.25,
        color: colors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: colors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: colors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: colors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: colors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: colors.textMuted,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: colors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: colors.textMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusLg),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.surfaceElevated,
          disabledForegroundColor: colors.textMuted,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: NearPaceSpacing.lg,
            vertical: NearPaceSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NearPaceSpacing.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: NearPaceSpacing.md,
            vertical: NearPaceSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NearPaceSpacing.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentText,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NearPaceSpacing.md,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: colors.textMuted),
        labelStyle: TextStyle(color: colors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
          borderSide: BorderSide(color: colors.accentText, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
          borderSide: BorderSide(color: colors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
          borderSide: BorderSide(color: colors.danger, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.accent,
        disabledColor: colors.surfaceElevated,
        labelStyle: TextStyle(
          color: colors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: colors.onAccent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NearPaceSpacing.radiusSheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusLg),
          side: BorderSide(color: colors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: TextStyle(color: colors.textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
          side: BorderSide(color: colors.border),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.onAccent;
          return colors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.accent;
          return colors.surfaceElevated;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return colors.border;
        }),
      ),
    );
  }
}
