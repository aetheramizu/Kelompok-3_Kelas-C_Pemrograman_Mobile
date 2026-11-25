import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/geo_point.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';

/// Draws a recorded GPS route on a clean canvas using `CustomPainter`.
///
/// Follows the NearPace MVP decision to avoid map tiles while still giving
/// runners an immediately recognizable trace of their route shape.
class RouteSketch extends StatelessWidget {
  const RouteSketch({
    super.key,
    required this.route,
    this.height = 180,
    this.compact = false,
    this.showEndpoints = true,
    this.showGrid = true,
    this.isLive = false,
    this.transparentBackground = false,
    this.strokeColorOverride,
    this.emptyMessage = 'Route sketch appears once GPS points are recorded',
  });

  final List<GeoPointLite> route;
  final double height;
  final bool compact;
  final bool showEndpoints;
  final bool showGrid;
  final bool isLive;
  final bool transparentBackground;
  final Color? strokeColorOverride;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final hasRoute = route.length >= 2;
    final radius = BorderRadius.circular(
      compact ? NearPaceSpacing.radiusSm : NearPaceSpacing.radiusLg,
    );
    final effectiveStroke = strokeColorOverride ?? colors.accent;

    return Semantics(
      label: hasRoute
          ? 'Recorded route sketch with ${route.length} GPS points'
          : 'No route sketch available',
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: transparentBackground ? Colors.transparent : colors.background,
          borderRadius: transparentBackground ? null : radius,
          border: transparentBackground
              ? null
              : Border.all(color: colors.border),
        ),
        clipBehavior: transparentBackground ? Clip.none : Clip.antiAlias,
        child: hasRoute
            ? CustomPaint(
                painter: _RouteSketchPainter(
                  points: route,
                  strokeColor: effectiveStroke,
                  glowColor: effectiveStroke.withValues(alpha: 0.24),
                  gridColor: colors.routeGrid,
                  startColor: strokeColorOverride ?? colors.textPrimary,
                  endColor: effectiveStroke,
                  backgroundColor: transparentBackground
                      ? Colors.transparent
                      : colors.background,
                  transparentBackground: transparentBackground,
                  strokeWidth: compact ? 2.6 : 3.6,
                  padding: compact ? 10 : 22,
                  showEndpoints: showEndpoints,
                  showGrid: showGrid && !transparentBackground,
                  isLive: isLive,
                ),
                child: const SizedBox.expand(),
              )
            : _RouteEmptyCanvas(
                compact: compact,
                message: emptyMessage,
                showGrid: showGrid && !transparentBackground,
                tintColor: strokeColorOverride,
              ),
      ),
    );
  }
}

class _RouteEmptyCanvas extends StatelessWidget {
  const _RouteEmptyCanvas({
    required this.compact,
    required this.message,
    required this.showGrid,
    this.tintColor,
  });

  final bool compact;
  final String message;
  final bool showGrid;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final iconColor = tintColor ?? colors.textMuted;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (showGrid)
          CustomPaint(painter: _GridOnlyPainter(gridColor: colors.routeGrid)),
        Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? 6 : NearPaceSpacing.md),
            child: compact
                ? Icon(Icons.route_rounded, size: 20, color: iconColor)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route_rounded, size: 28, color: iconColor),
                      const SizedBox(height: NearPaceSpacing.xs),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tintColor ?? colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _GridOnlyPainter extends CustomPainter {
  const _GridOnlyPainter({required this.gridColor});

  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;

    const step = 24.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridOnlyPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor;
}

class _RouteSketchPainter extends CustomPainter {
  const _RouteSketchPainter({
    required this.points,
    required this.strokeColor,
    required this.glowColor,
    required this.gridColor,
    required this.startColor,
    required this.endColor,
    required this.backgroundColor,
    required this.transparentBackground,
    required this.strokeWidth,
    required this.padding,
    required this.showEndpoints,
    required this.showGrid,
    required this.isLive,
  });

  final List<GeoPointLite> points;
  final Color strokeColor;
  final Color glowColor;
  final Color gridColor;
  final Color startColor;
  final Color endColor;
  final Color backgroundColor;
  final bool transparentBackground;
  final double strokeWidth;
  final double padding;
  final bool showEndpoints;
  final bool showGrid;
  final bool isLive;

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      final gridPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 0.8;
      const step = 24.0;
      for (var x = step; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (var y = step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    if (points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final midLatRad = ((minLat + maxLat) / 2) * math.pi / 180;
    final cosLat = math.cos(midLatRad).abs().clamp(0.2, 1.0);

    final rawSpanX = (maxLng - minLng) * cosLat;
    final rawSpanY = maxLat - minLat;
    final spanX = rawSpanX == 0 ? 0.0005 : rawSpanX;
    final spanY = rawSpanY == 0 ? 0.0005 : rawSpanY;

    final drawWidth = math.max(1.0, size.width - padding * 2);
    final drawHeight = math.max(1.0, size.height - padding * 2);
    final scale = math.min(drawWidth / spanX, drawHeight / spanY);

    final projectedWidth = spanX * scale;
    final projectedHeight = spanY * scale;
    final offsetX = (size.width - projectedWidth) / 2;
    final offsetY = (size.height - projectedHeight) / 2;

    Offset project(GeoPointLite point) {
      final x = offsetX + (point.longitude - minLng) * cosLat * scale;
      final y = offsetY + (maxLat - point.latitude) * scale;
      return Offset(x, y);
    }

    final offsets = points.map(project).toList(growable: false);
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }

    // Subtle outer glow keeps the route legible against dark and light grids.
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    final routePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, routePaint);

    if (showEndpoints) {
      final start = offsets.first;
      final end = offsets.last;

      // Start marker (ringed dot on opaque canvases; clean dot on transparent stickers).
      if (!transparentBackground) {
        canvas.drawCircle(
          start,
          strokeWidth + 2,
          Paint()..color = backgroundColor,
        );
      }
      canvas.drawCircle(start, strokeWidth + 0.5, Paint()..color = startColor);

      // End / current position marker.
      if (isLive) {
        canvas.drawCircle(
          end,
          strokeWidth + 7,
          Paint()..color = endColor.withValues(alpha: 0.25),
        );
      }
      if (!transparentBackground) {
        canvas.drawCircle(
          end,
          strokeWidth + 2.5,
          Paint()..color = backgroundColor,
        );
      }
      canvas.drawCircle(end, strokeWidth + 1, Paint()..color = endColor);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteSketchPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.transparentBackground != transparentBackground ||
        oldDelegate.isLive != isLive;
  }
}
