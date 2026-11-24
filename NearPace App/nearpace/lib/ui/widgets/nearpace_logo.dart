import 'package:material_ui/material_ui.dart';

import '../../theme/nearpace_colors.dart';

/// Branded Option A ("Route Trace N") NearPace vector brand mark.
class NearPaceLogo extends StatelessWidget {
  const NearPaceLogo({
    super.key,
    this.size = 72,
    this.strokeColor,
    this.dotColor,
  });

  final double size;
  final Color? strokeColor;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final stroke = strokeColor ?? colors.accent;
    final dot = dotColor ?? colors.performanceGreen;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: NearPaceMarkPainter(strokeColor: stroke, dotColor: dot),
      ),
    );
  }
}

/// Custom painter for the Option A ("Route Trace N") vector geometry.
class NearPaceMarkPainter extends CustomPainter {
  const NearPaceMarkPainter({
    required this.strokeColor,
    required this.dotColor,
  });

  final Color strokeColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 256.0;
    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(18.0, 18.0);
    canvas.scale(0.859375, 0.859375);

    final routePath = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(44, 188)
      ..lineTo(44, 68)
      ..lineTo(60, 52)
      ..lineTo(84, 52)
      ..lineTo(172, 140)
      ..lineTo(172, 124)
      ..arcToPoint(const Offset(212, 124), radius: const Radius.circular(20))
      ..lineTo(212, 188)
      ..lineTo(196, 204)
      ..lineTo(172, 204)
      ..lineTo(84, 116)
      ..lineTo(84, 188)
      ..arcToPoint(const Offset(44, 188), radius: const Radius.circular(20))
      ..close()
      ..addOval(Rect.fromCircle(center: const Offset(64, 188), radius: 8));

    canvas.drawPath(routePath, Paint()..color = strokeColor);
    canvas.drawCircle(const Offset(192, 68), 20, Paint()..color = dotColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NearPaceMarkPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.dotColor != dotColor;
}
