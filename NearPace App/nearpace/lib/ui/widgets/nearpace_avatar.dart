import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/nearpace_colors.dart';

/// Preset avatar character descriptor.
class AvatarCharacter {
  const AvatarCharacter({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
  });

  final String id;
  final String name;
  final String category; // 'runners' or 'mascots'
  final String description;
}

/// Official 12 flat-sport NearPace vector avatar presets.
const List<AvatarCharacter> kNearPaceAvatars = [
  // 8 Human Runners
  AvatarCharacter(
    id: 'volt_sprinter',
    name: 'Volt Sprinter',
    category: 'runners',
    description: 'Dynamic sprinter with volt sweatband and focused gaze',
  ),
  AvatarCharacter(
    id: 'pace_queen',
    name: 'Pace Queen',
    category: 'runners',
    description: 'High-cadence runner with streamlined ponytail & visor',
  ),
  AvatarCharacter(
    id: 'hijab_runner',
    name: 'Hijab Runner',
    category: 'runners',
    description: 'Dedicated endurance athlete wearing aero sports hijab',
  ),
  AvatarCharacter(
    id: 'trail_explorer',
    name: 'Trail Explorer',
    category: 'runners',
    description: 'Off-road ultra runner with mountain cap and trail goggles',
  ),
  AvatarCharacter(
    id: 'night_runner',
    name: 'Night Runner',
    category: 'runners',
    description: 'After-hours runner with neon reflective visor and dark specs',
  ),
  AvatarCharacter(
    id: 'beat_jogger',
    name: 'Beat Jogger',
    category: 'runners',
    description: 'Rhythm-driven strider with over-ear workout headphones',
  ),
  AvatarCharacter(
    id: 'marathon_pro',
    name: 'Marathon Pro',
    category: 'runners',
    description: 'Elite long-distance racer with classic striped sweatband',
  ),
  AvatarCharacter(
    id: 'morning_strider',
    name: 'Morning Strider',
    category: 'runners',
    description: 'Dawn-breaker runner catching the golden morning light',
  ),

  // 4 Sport Mascots
  AvatarCharacter(
    id: 'volt_cheetah',
    name: 'Volt Cheetah',
    category: 'mascots',
    description: 'Explosive speed mascot with aerodynamic volt teardrops',
  ),
  AvatarCharacter(
    id: 'swift_fox',
    name: 'Swift Fox',
    category: 'mascots',
    description: 'Nimble tactical navigator with alert athletic ears',
  ),
  AvatarCharacter(
    id: 'stride_owl',
    name: 'Stride Owl',
    category: 'mascots',
    description: 'Focused nocturnal pacekeeper with wide luminous eyes',
  ),
  AvatarCharacter(
    id: 'apex_wolf',
    name: 'Apex Wolf',
    category: 'mascots',
    description: 'Resilient pack endurance leader built for distance',
  ),
];

/// Renders either a custom flat-sport vector character or fallback initials.
class NearPaceAvatar extends StatelessWidget {
  const NearPaceAvatar({
    super.key,
    this.avatarId,
    this.name = 'Runner',
    this.size = 44,
    this.onTap,
  });

  final String? avatarId;
  final String name;
  final double size;
  final VoidCallback? onTap;

  String _computeInitials(String rawName) {
    final parts = rawName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'N';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last.substring(0, 1)
        : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final hasValidAvatar =
        avatarId != null && kNearPaceAvatars.any((a) => a.id == avatarId);

    Widget avatarContent;
    if (hasValidAvatar) {
      avatarContent = ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: _AvatarPainter(avatarId: avatarId!),
        ),
      );
    } else {
      // Initials fallback
      final initials = _computeInitials(name);
      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.deepGreenSurface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: colors.accentText,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.38,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatarContent,
      );
    }

    return avatarContent;
  }
}

/// CustomPainter that renders each of the 12 characters mathematically on a square canvas.
class _AvatarPainter extends CustomPainter {
  const _AvatarPainter({required this.avatarId});

  final String avatarId;

  // NearPace Palette
  static const Color cBg = Color(0xFF1C211E);
  static const Color cVolt = Color(0xFFB7F36B);
  static const Color cGreen = Color(0xFF4ADE80);
  static const Color cDark = Color(0xFF111612);
  static const Color cLight = Color(0xFFF2F5F0);
  static const Color cDarkMuted = Color(0xFF38433C);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Background circle
    final bgPaint = Paint()..color = cBg;
    canvas.drawCircle(center, radius, bgPaint);

    // Border ring
    final ringPaint = Paint()
      ..color = cVolt.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04;
    canvas.drawCircle(center, radius - (w * 0.02), ringPaint);

    switch (avatarId) {
      case 'volt_sprinter':
        _paintVoltSprinter(canvas, size);
        break;
      case 'pace_queen':
        _paintPaceQueen(canvas, size);
        break;
      case 'hijab_runner':
        _paintHijabRunner(canvas, size);
        break;
      case 'trail_explorer':
        _paintTrailExplorer(canvas, size);
        break;
      case 'night_runner':
        _paintNightRunner(canvas, size);
        break;
      case 'beat_jogger':
        _paintBeatJogger(canvas, size);
        break;
      case 'marathon_pro':
        _paintMarathonPro(canvas, size);
        break;
      case 'morning_strider':
        _paintMorningStrider(canvas, size);
        break;
      case 'volt_cheetah':
        _paintVoltCheetah(canvas, size);
        break;
      case 'swift_fox':
        _paintSwiftFox(canvas, size);
        break;
      case 'stride_owl':
        _paintStrideOwl(canvas, size);
        break;
      case 'apex_wolf':
        _paintApexWolf(canvas, size);
        break;
      default:
        _paintVoltSprinter(canvas, size);
    }
  }

  // --- 1. Volt Sprinter (Headband + confident runner) ---
  void _paintVoltSprinter(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Neck & shoulders
    p.color = cVolt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.68, w * 0.5, h * 0.35),
        Radius.circular(w * 0.2),
      ),
      p,
    );

    // Face / head
    p.color = cLight;
    canvas.drawCircle(Offset(w * 0.5, h * 0.44), w * 0.26, p);

    // Hair
    p.color = cDark;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.40), radius: w * 0.26),
      math.pi,
      math.pi,
      true,
      p,
    );

    // Volt Headband
    p.color = cVolt;
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.24, h * 0.32, w * 0.52, h * 0.1),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(band, p);

    // Eyes
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.42, h * 0.46), w * 0.035, p);
    canvas.drawCircle(Offset(w * 0.58, h * 0.46), w * 0.035, p);
  }

  // --- 2. Pace Queen (Ponytail + Visor) ---
  void _paintPaceQueen(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Ponytail (side swoosh)
    p.color = cDark;
    final path = Path()
      ..moveTo(w * 0.6, h * 0.3)
      ..quadraticBezierTo(w * 0.88, h * 0.35, w * 0.82, h * 0.65)
      ..quadraticBezierTo(w * 0.72, h * 0.5, w * 0.6, h * 0.45)
      ..close();
    canvas.drawPath(path, p);

    // Neck & collar
    p.color = cGreen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * 0.7, w * 0.44, h * 0.32),
        Radius.circular(w * 0.18),
      ),
      p,
    );

    // Face
    p.color = cLight;
    canvas.drawCircle(Offset(w * 0.48, h * 0.46), w * 0.24, p);

    // Visor cap
    p.color = cVolt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.32, w * 0.56, h * 0.1),
        Radius.circular(w * 0.05),
      ),
      p,
    );
    // Visor brim
    p.color = cDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * 0.40, w * 0.44, h * 0.04),
        Radius.circular(w * 0.02),
      ),
      p,
    );

    // Eyes
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.42, h * 0.48), w * 0.03, p);
    canvas.drawCircle(Offset(w * 0.56, h * 0.48), w * 0.03, p);
  }

  // --- 3. Hijab Runner (Aero Sport Hijab) ---
  void _paintHijabRunner(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Outer sport hijab
    p.color = cDarkMuted;
    final hijabPath = Path()
      ..moveTo(w * 0.5, h * 0.16)
      ..quadraticBezierTo(w * 0.8, h * 0.25, w * 0.78, h * 0.65)
      ..quadraticBezierTo(w * 0.75, h * 0.88, w * 0.5, h * 0.92)
      ..quadraticBezierTo(w * 0.25, h * 0.88, w * 0.22, h * 0.65)
      ..quadraticBezierTo(w * 0.2, h * 0.25, w * 0.5, h * 0.16)
      ..close();
    canvas.drawPath(hijabPath, p);

    // Inner face opening
    p.color = cLight;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.48),
        width: w * 0.34,
        height: w * 0.42,
      ),
      p,
    );

    // Sport headband under hijab
    p.color = cVolt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.35, h * 0.32, w * 0.3, h * 0.06),
        Radius.circular(w * 0.03),
      ),
      p,
    );

    // Expressive eyes
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.44, h * 0.47), w * 0.03, p);
    canvas.drawCircle(Offset(w * 0.56, h * 0.47), w * 0.03, p);

    // Collar
    p.color = cVolt;
    canvas.drawCircle(Offset(w * 0.5, h * 0.86), w * 0.08, p);
  }

  // --- 4. Trail Explorer (Cap + hydration badge) ---
  void _paintTrailExplorer(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Shoulders
    p.color = const Color(0xFF2C3E2D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.7, w * 0.56, h * 0.3),
        Radius.circular(w * 0.2),
      ),
      p,
    );

    // Face
    p.color = cLight;
    canvas.drawCircle(Offset(w * 0.5, h * 0.46), w * 0.24, p);

    // Trail Cap
    p.color = cVolt;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.42), radius: w * 0.25),
      math.pi,
      math.pi,
      true,
      p,
    );
    // Cap brim
    p.color = cDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.38, w * 0.6, h * 0.07),
        Radius.circular(w * 0.035),
      ),
      p,
    );

    // Eyes with sunglasses
    p.color = const Color(0xFF1E2822);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.36, h * 0.45, w * 0.12, h * 0.08),
        Radius.circular(w * 0.03),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.52, h * 0.45, w * 0.12, h * 0.08),
        Radius.circular(w * 0.03),
      ),
      p,
    );
  }

  // --- 5. Night Runner (Neon Stripes + Reflective Visor) ---
  void _paintNightRunner(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Dark shoulders with neon stripe
    p.color = cDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.68, w * 0.6, h * 0.32),
        Radius.circular(w * 0.2),
      ),
      p,
    );
    p.color = cVolt;
    canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.78, w * 0.6, h * 0.05), p);

    // Face in night tone
    p.color = const Offset(1, 1).dx > 0 ? cLight : cLight;
    canvas.drawCircle(Offset(w * 0.5, h * 0.44), w * 0.24, p);

    // Night goggles
    p.color = cDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, h * 0.4, w * 0.4, h * 0.12),
        Radius.circular(w * 0.04),
      ),
      p,
    );
    // Glowing neon lenses
    p.color = cVolt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.33, h * 0.42, w * 0.14, h * 0.08),
        Radius.circular(w * 0.02),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.53, h * 0.42, w * 0.14, h * 0.08),
        Radius.circular(w * 0.02),
      ),
      p,
    );
  }

  // --- 6. Beat Jogger (Workout Headphones) ---
  void _paintBeatJogger(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Headphones band (arches over head)
    p.color = cVolt;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = w * 0.06;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.42), radius: w * 0.28),
      math.pi * 0.85,
      math.pi * 1.3,
      false,
      p,
    );
    p.style = PaintingStyle.fill;

    // Face
    p.color = cLight;
    canvas.drawCircle(Offset(w * 0.5, h * 0.46), w * 0.23, p);

    // Hair
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.5, h * 0.36), w * 0.18, p);

    // Headphone Ear cups
    p.color = cGreen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.4, w * 0.1, h * 0.18),
        Radius.circular(w * 0.04),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.7, h * 0.4, w * 0.1, h * 0.18),
        Radius.circular(w * 0.04),
      ),
      p,
    );

    // Eyes
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.44, h * 0.48), w * 0.03, p);
    canvas.drawCircle(Offset(w * 0.56, h * 0.48), w * 0.03, p);
  }

  // --- 7. Marathon Pro (Bib & Classic Sweatband) ---
  void _paintMarathonPro(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Singlet body
    p.color = cLight;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.68, w * 0.56, h * 0.32),
        Radius.circular(w * 0.18),
      ),
      p,
    );
    // Singlet stripe
    p.color = cVolt;
    canvas.drawRect(Rect.fromLTWH(w * 0.46, h * 0.68, w * 0.08, h * 0.32), p);

    // Face
    p.color = const Color(0xFFF7D9BC);
    canvas.drawCircle(Offset(w * 0.5, h * 0.44), w * 0.24, p);

    // Sweatband
    p.color = cGreen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, h * 0.32, w * 0.52, h * 0.09),
        Radius.circular(w * 0.04),
      ),
      p,
    );

    // Eyes
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.43, h * 0.46), w * 0.03, p);
    canvas.drawCircle(Offset(w * 0.57, h * 0.46), w * 0.03, p);
  }

  // --- 8. Morning Strider (Golden Dawn Aura) ---
  void _paintMorningStrider(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Sun disc backdrop
    p.color = const Color(0xFFFBBF24).withValues(alpha: 0.35);
    canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.36, p);

    // Shoulders
    p.color = cVolt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, h * 0.68, w * 0.52, h * 0.32),
        Radius.circular(w * 0.18),
      ),
      p,
    );

    // Face
    p.color = cLight;
    canvas.drawCircle(Offset(w * 0.5, h * 0.44), w * 0.23, p);

    // Hair
    p.color = const Color(0xFFD97706);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.40), radius: w * 0.23),
      math.pi * 0.9,
      math.pi * 1.2,
      true,
      p,
    );

    // Eyes
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.44, h * 0.46), w * 0.03, p);
    canvas.drawCircle(Offset(w * 0.56, h * 0.46), w * 0.03, p);
  }

  // --- 9. Volt Cheetah (Fast Mascot) ---
  void _paintVoltCheetah(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Cheetah Ears
    p.color = cVolt;
    canvas.drawCircle(Offset(w * 0.32, h * 0.28), w * 0.12, p);
    canvas.drawCircle(Offset(w * 0.68, h * 0.28), w * 0.12, p);
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.32, h * 0.28), w * 0.06, p);
    canvas.drawCircle(Offset(w * 0.68, h * 0.28), w * 0.06, p);

    // Head
    p.color = cVolt;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.3, p);

    // Muzzle
    p.color = cLight;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.62),
        width: w * 0.26,
        height: w * 0.18,
      ),
      p,
    );

    // Nose
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.5, h * 0.58), w * 0.04, p);

    // Cheetah tear lines
    p.strokeWidth = w * 0.03;
    p.style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.4, h * 0.48), Offset(w * 0.42, h * 0.66), p);
    canvas.drawLine(Offset(w * 0.6, h * 0.48), Offset(w * 0.58, h * 0.66), p);
    p.style = PaintingStyle.fill;

    // Eyes
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.4, h * 0.46), w * 0.04, p);
    canvas.drawCircle(Offset(w * 0.6, h * 0.46), w * 0.04, p);
  }

  // --- 10. Swift Fox (Clever Endurance Fox) ---
  void _paintSwiftFox(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Pointy Fox Ears
    p.color = const Color(0xFFF97316);
    final leftEar = Path()
      ..moveTo(w * 0.25, h * 0.45)
      ..lineTo(w * 0.22, h * 0.18)
      ..lineTo(w * 0.45, h * 0.32)
      ..close();
    final rightEar = Path()
      ..moveTo(w * 0.75, h * 0.45)
      ..lineTo(w * 0.78, h * 0.18)
      ..lineTo(w * 0.55, h * 0.32)
      ..close();
    canvas.drawPath(leftEar, p);
    canvas.drawPath(rightEar, p);

    // Head base
    p.color = const Color(0xFFF97316);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.28, p);

    // White cheeks & muzzle
    p.color = cLight;
    final muzzle = Path()
      ..moveTo(w * 0.25, h * 0.5)
      ..lineTo(w * 0.5, h * 0.72)
      ..lineTo(w * 0.75, h * 0.5)
      ..quadraticBezierTo(w * 0.5, h * 0.58, w * 0.25, h * 0.5)
      ..close();
    canvas.drawPath(muzzle, p);

    // Volt sports collar
    p.color = cVolt;
    canvas.drawCircle(Offset(w * 0.5, h * 0.74), w * 0.06, p);

    // Nose
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.5, h * 0.66), w * 0.035, p);

    // Eyes
    canvas.drawCircle(Offset(w * 0.4, h * 0.46), w * 0.035, p);
    canvas.drawCircle(Offset(w * 0.6, h * 0.46), w * 0.035, p);
  }

  // --- 11. Stride Owl (Focused Nocturnal Owl) ---
  void _paintStrideOwl(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Owl Body & Head
    p.color = const Color(0xFF3B4840);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.32, p);

    // Ear tufts
    final leftTuft = Path()
      ..moveTo(w * 0.3, h * 0.3)
      ..lineTo(w * 0.24, h * 0.18)
      ..lineTo(w * 0.4, h * 0.24)
      ..close();
    final rightTuft = Path()
      ..moveTo(w * 0.7, h * 0.3)
      ..lineTo(w * 0.76, h * 0.18)
      ..lineTo(w * 0.6, h * 0.24)
      ..close();
    canvas.drawPath(leftTuft, p);
    canvas.drawPath(rightTuft, p);

    // Big luminous eye discs
    p.color = cVolt;
    canvas.drawCircle(Offset(w * 0.38, h * 0.48), w * 0.13, p);
    canvas.drawCircle(Offset(w * 0.62, h * 0.48), w * 0.13, p);

    // Pupils
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.38, h * 0.48), w * 0.07, p);
    canvas.drawCircle(Offset(w * 0.62, h * 0.48), w * 0.07, p);

    // Beak
    p.color = const Color(0xFFF59E0B);
    final beak = Path()
      ..moveTo(w * 0.46, h * 0.54)
      ..lineTo(w * 0.54, h * 0.54)
      ..lineTo(w * 0.5, h * 0.66)
      ..close();
    canvas.drawPath(beak, p);
  }

  // --- 12. Apex Wolf (Pack Endurance Leader) ---
  void _paintApexWolf(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint();

    // Wolf ears
    p.color = const Color(0xFF4A5568);
    final leftEar = Path()
      ..moveTo(w * 0.26, h * 0.4)
      ..lineTo(w * 0.22, h * 0.18)
      ..lineTo(w * 0.42, h * 0.28)
      ..close();
    final rightEar = Path()
      ..moveTo(w * 0.74, h * 0.4)
      ..lineTo(w * 0.78, h * 0.18)
      ..lineTo(w * 0.58, h * 0.28)
      ..close();
    canvas.drawPath(leftEar, p);
    canvas.drawPath(rightEar, p);

    // Head
    p.color = const Color(0xFF4A5568);
    canvas.drawCircle(Offset(w * 0.5, h * 0.48), w * 0.3, p);

    // Snout
    p.color = cLight;
    final snout = Path()
      ..moveTo(w * 0.34, h * 0.48)
      ..lineTo(w * 0.5, h * 0.72)
      ..lineTo(w * 0.66, h * 0.48)
      ..close();
    canvas.drawPath(snout, p);

    // Nose
    p.color = cDark;
    canvas.drawCircle(Offset(w * 0.5, h * 0.68), w * 0.04, p);

    // Volt war paint / athletic markings under eyes
    p.color = cVolt;
    canvas.drawRect(Rect.fromLTWH(w * 0.32, h * 0.44, w * 0.08, w * 0.025), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.60, h * 0.44, w * 0.08, w * 0.025), p);

    // Alert eyes
    p.color = cVolt;
    canvas.drawCircle(Offset(w * 0.38, h * 0.42), w * 0.035, p);
    canvas.drawCircle(Offset(w * 0.62, h * 0.42), w * 0.035, p);
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) {
    return oldDelegate.avatarId != avatarId;
  }
}
