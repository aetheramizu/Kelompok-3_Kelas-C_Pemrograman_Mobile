import 'package:material_ui/material_ui.dart';

/// Consistent 4/8dp spacing, corner radii, touch targets, and motion tokens.
class NearPaceSpacing {
  const NearPaceSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusSheet = 24;
  static const double radiusPill = 999;

  /// Android minimum recommended touch target (exceeds iOS 44pt minimum).
  static const double minTapTarget = 48;

  /// Maximum readable content width on tablets and landscape phones.
  static const double maxContentWidth = 640;

  /// Responsive horizontal page gutter.
  static double pageGutter(double viewportWidth) {
    if (viewportWidth >= 720) return 32;
    if (viewportWidth >= 420) return 20;
    return 16;
  }
}

/// Shared purposeful motion timings and curves.
class NearPaceMotion {
  const NearPaceMotion._();

  static const Duration press = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasis = Duration(milliseconds: 320);

  /// Crisp decelerating ease-out curve for entrances and state settles.
  static const Curve easeOut = Cubic(0.23, 1.0, 0.32, 1.0);

  static Duration resolve(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}
