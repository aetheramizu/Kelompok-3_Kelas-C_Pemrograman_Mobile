import 'package:flutter/material.dart';

/// Token warna Resepin — sumber: dokumen desain Fase 3 yang disetujui.
/// Jangan hardcode warna lain di layar; tambahkan token baru di sini bila perlu.
abstract final class ResepinColors {
  static const background = Color(0xFFFFFBEB);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F172A);
  static const inkMuted = Color(0xFF475569);
  static const primary = Color(0xFF065F46);
  static const primaryStrong = Color(0xFF047857);
  static const primaryDeep = Color(0xFF064E3B);
  static const accent = Color(0xFF9A3412);
  static const onAccent = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8E0D0);
  static const borderStrong = Color(0xFFC9BBA4);
  static const destructive = Color(0xFFDC2626);
  static const imagePlaceholder = Color(0xFFF3EDE0);
}

/// Skala spacing berbasis 4/8 dp.
abstract final class ResepinSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

/// Hanya tiga nilai radius, sesuai desain.
abstract final class ResepinRadius {
  static const chip = 8.0;
  static const card = 12.0;
  static const detailImage = 16.0;
}

/// Gaya kartu tunggal untuk seluruh aplikasi: putih flat dengan border
/// tipis, tanpa elevasi maupun shadow (kebijakan elevasi desain).
abstract final class ResepinDecorations {
  static final BoxDecoration card = BoxDecoration(
    color: ResepinColors.surface,
    borderRadius: BorderRadius.circular(ResepinRadius.card),
    border: Border.all(color: ResepinColors.border),
  );
}

/// Batas lebar konten agar baris teks tetap nyaman dibaca di layar lebar
/// (web/tablet); di ponsel nilainya lebih besar dari layar sehingga tidak
/// berpengaruh.
abstract final class ResepinLayout {
  static const maxContentWidth = 560.0;
}

/// Padding horizontal adaptif untuk konten yang dapat digulir: minimal
/// [min] (16 pada ponsel) dan bertambah di layar lebar (web/tablet)
/// sehingga lebar konten tetap nyaman dibaca (~560).
double resepinGutter(BuildContext context, {double min = ResepinSpacing.lg}) {
  final width = MediaQuery.sizeOf(context).width;
  final gutter = (width - ResepinLayout.maxContentWidth) / 2;
  return gutter > min ? gutter : min;
}

abstract final class ResepinTypography {
  /// Nama family font judul; harus sama dengan deklarasi di pubspec.yaml.
  static const fraunces = 'Fraunces';
}

/// Tema light-only Resepin. Judul memakai Fraunces (aset lokal), teks isi
/// memakai font sistem agar text scaling tetap native.
ThemeData buildResepinTheme() {
  final scheme = ColorScheme.light(
    primary: ResepinColors.primary,
    onPrimary: Colors.white,
    secondary: ResepinColors.accent,
    onSecondary: ResepinColors.onAccent,
    error: ResepinColors.destructive,
    onError: Colors.white,
    surface: ResepinColors.surface,
    onSurface: ResepinColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ResepinColors.background,
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: ResepinColors.surface,
      foregroundColor: ResepinColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(
      color: ResepinColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ResepinColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: ResepinSpacing.lg,
        vertical: ResepinSpacing.md,
      ),
      border: _inputBorder(ResepinColors.borderStrong),
      enabledBorder: _inputBorder(ResepinColors.borderStrong),
      focusedBorder: _inputBorder(ResepinColors.primaryStrong),
      hintStyle: const TextStyle(color: ResepinColors.inkMuted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ResepinColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: ResepinColors.primary.withValues(alpha: 0.12),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? ResepinColors.primaryStrong
              : ResepinColors.inkMuted,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 13,
          height: 1.3,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected
              ? ResepinColors.primaryStrong
              : ResepinColors.inkMuted,
        );
      }),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ResepinColors.primaryStrong),
    ),
  );
}

OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(ResepinRadius.chip),
  borderSide: BorderSide(color: color),
);

/// Gaya Fraunces dengan axis variabel: wght 600 (SemiBold) dan opsz
/// (optical size) dinaikkan agar judul terlihat tajam khas editorial.
TextStyle _fraunces(
  double size,
  double height,
  Color color, {
  required double opsz,
}) {
  return TextStyle(
    fontFamily: ResepinTypography.fraunces,
    fontSize: size,
    height: height,
    fontWeight: FontWeight.w600,
    color: color,
    fontVariations: <FontVariation>[
      const FontVariation('wght', 600),
      FontVariation('opsz', opsz),
    ],
  );
}

final TextTheme _textTheme = TextTheme(
  // Judul layar & nama resep di detail (28sp) dan judul kartu saran (20sp).
  displaySmall: _fraunces(28, 1.2, ResepinColors.ink, opsz: 72),
  titleLarge: _fraunces(20, 1.3, ResepinColors.ink, opsz: 40),
  // Section header (16sp) dan judul kartu grid (15sp di layar).
  titleMedium: const TextStyle(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: ResepinColors.ink,
  ),
  bodyMedium: const TextStyle(
    fontSize: 15,
    height: 1.5,
    color: ResepinColors.ink,
  ),
  bodySmall: const TextStyle(
    fontSize: 13,
    height: 1.3,
    color: ResepinColors.inkMuted,
  ),
  labelLarge: const TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: ResepinColors.primaryStrong,
  ),
);
