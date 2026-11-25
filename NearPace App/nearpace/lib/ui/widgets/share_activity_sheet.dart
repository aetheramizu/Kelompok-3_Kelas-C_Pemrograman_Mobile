import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/activity.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import 'nearpace_logo.dart';
import 'route_sketch.dart';

enum ShareCardMode { transparentSticker, darkBrandCard }

enum OverlayTone { volt, white }

/// Strava-style transparent sticker and dark brand card activity exporter.
class ShareActivitySheet extends StatefulWidget {
  const ShareActivitySheet({super.key, required this.activity});

  final Activity activity;

  static Future<void> show(BuildContext context, {required Activity activity}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareActivitySheet(activity: activity),
    );
  }

  @override
  State<ShareActivitySheet> createState() => _ShareActivitySheetState();
}

class _ShareActivitySheetState extends State<ShareActivitySheet> {
  final GlobalKey _cardKey = GlobalKey();
  ShareCardMode _mode = ShareCardMode.transparentSticker;
  OverlayTone _overlayTone = OverlayTone.volt;
  bool _isProcessing = false;
  String? _statusNotice;

  Future<Uint8List?> _capturePngBytes() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    setState(() {
      _isProcessing = true;
      _statusNotice = null;
    });

    try {
      final bytes = await _capturePngBytes();
      if (bytes == null) {
        setState(() => _statusNotice = 'Failed to generate image.');
        return;
      }

      await Gal.putImageBytes(
        bytes,
        name:
            'nearpace_${widget.activity.id}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        setState(() => _statusNotice = 'Saved to Gallery successfully!');
      }
    } on GalException catch (e) {
      if (mounted) {
        final message = e.type == GalExceptionType.permissionDenied
            ? 'Gallery permission denied. Allow photo access in Settings to save.'
            : 'Unable to save image: ${e.type.message}';
        setState(() => _statusNotice = message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusNotice = 'Unable to save image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _shareImage() async {
    setState(() {
      _isProcessing = true;
      _statusNotice = null;
    });

    try {
      final bytes = await _capturePngBytes();
      if (bytes == null) {
        setState(() => _statusNotice = 'Failed to generate image.');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/nearpace_${widget.activity.id}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      final distanceKm = NearPaceFormatters.distanceKm(
        widget.activity.distanceM,
      );
      final pace = NearPaceFormatters.paceWithUnit(
        widget.activity.avgPaceSecPerKm,
      );
      final text = 'Ran $distanceKm with NearPace (avg pace $pace)!';

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: text),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _statusNotice = 'Unable to share: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final activity = widget.activity;

    final distance = NearPaceFormatters.distanceKm(activity.distanceM);
    final duration = NearPaceFormatters.durationClock(activity.duration);
    final pace = NearPaceFormatters.paceWithUnit(activity.avgPaceSecPerKm);
    final date = NearPaceFormatters.activityTimestamp(activity.startedAt);

    final isTransparent = _mode == ShareCardMode.transparentSticker;
    final overlayColor = _overlayTone == OverlayTone.volt
        ? colors.accent
        : const Color(0xFFF2F5F0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NearPaceSpacing.radiusLg),
        ),
        border: Border(
          top: BorderSide(color: colors.border),
          left: BorderSide(color: colors.border),
          right: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: NearPaceSpacing.sm),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NearPaceSpacing.md,
              NearPaceSpacing.sm,
              NearPaceSpacing.md,
              NearPaceSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Share Activity', style: textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: colors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Mode Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NearPaceSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<ShareCardMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ShareCardMode.transparentSticker,
                        label: Text(
                          'Transparent Sticker',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ButtonSegment(
                        value: ShareCardMode.darkBrandCard,
                        label: Text(
                          'Dark Brand Card',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (set) {
                      setState(() => _mode = set.first);
                    },
                  ),
                ),
              ],
            ),
          ),

          if (isTransparent) ...[
            const SizedBox(height: NearPaceSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.md,
              ),
              child: Row(
                children: [
                  Text(
                    'Overlay tone:',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(width: NearPaceSpacing.sm),
                  ChoiceChip(
                    label: const Text('Volt #B7F36B'),
                    selected: _overlayTone == OverlayTone.volt,
                    showCheckmark: false,
                    selectedColor: colors.accent,
                    backgroundColor: colors.surfaceElevated,
                    side: BorderSide(
                      color: _overlayTone == OverlayTone.volt
                          ? colors.accent
                          : colors.border,
                    ),
                    labelStyle: TextStyle(
                      color: _overlayTone == OverlayTone.volt
                          ? colors.onAccent
                          : colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) =>
                        setState(() => _overlayTone = OverlayTone.volt),
                  ),
                  const SizedBox(width: NearPaceSpacing.xs),
                  ChoiceChip(
                    label: const Text('Pure White'),
                    selected: _overlayTone == OverlayTone.white,
                    showCheckmark: false,
                    selectedColor: const Color(0xFFF2F5F0),
                    backgroundColor: colors.surfaceElevated,
                    side: BorderSide(
                      color: _overlayTone == OverlayTone.white
                          ? const Color(0xFFF2F5F0)
                          : colors.border,
                    ),
                    labelStyle: TextStyle(
                      color: _overlayTone == OverlayTone.white
                          ? colors.onAccent
                          : colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) =>
                        setState(() => _overlayTone = OverlayTone.white),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: NearPaceSpacing.sm),

          // Card preview viewport: checkerboard lives OUTSIDE RepaintBoundary
          // so exported transparent PNGs stay 100% alpha-transparent.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.md,
              ),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(NearPaceSpacing.radiusMd),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isTransparent
                          ? Colors.transparent
                          : colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(
                        NearPaceSpacing.radiusMd,
                      ),
                      border: Border.all(color: colors.border),
                    ),
                    child: CustomPaint(
                      key: const ValueKey('share-preview-checkerboard'),
                      painter: isTransparent
                          ? const _TransparencyCheckerboardPainter()
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(NearPaceSpacing.md),
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: Container(
                            width: 296,
                            padding: const EdgeInsets.all(NearPaceSpacing.md),
                            decoration: BoxDecoration(
                              color: isTransparent
                                  ? Colors.transparent
                                  : colors.background,
                              borderRadius: BorderRadius.circular(
                                isTransparent ? 0 : NearPaceSpacing.radiusMd,
                              ),
                              border: isTransparent
                                  ? null
                                  : Border.all(
                                      color: colors.border,
                                      width: 1.5,
                                    ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Branding header
                                Row(
                                  children: [
                                    NearPaceLogo(
                                      size: 26,
                                      strokeColor: isTransparent
                                          ? overlayColor
                                          : colors.accent,
                                      dotColor: isTransparent
                                          ? overlayColor
                                          : colors.performanceGreen,
                                    ),
                                    const SizedBox(width: NearPaceSpacing.xs),
                                    Text(
                                      'NearPace',
                                      style: textTheme.titleSmall?.copyWith(
                                        color: isTransparent
                                            ? overlayColor
                                            : colors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(width: NearPaceSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        date,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: isTransparent
                                              ? overlayColor.withValues(
                                                  alpha: 0.8,
                                                )
                                              : colors.textMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: NearPaceSpacing.md),

                                // Route sketch (transparent & tone-matched in sticker mode)
                                Center(
                                  child: SizedBox(
                                    width: 236,
                                    height: 140,
                                    child: RouteSketch(
                                      route: activity.route,
                                      height: 140,
                                      showGrid: !isTransparent,
                                      compact: true,
                                      transparentBackground: isTransparent,
                                      strokeColorOverride: isTransparent
                                          ? overlayColor
                                          : null,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: NearPaceSpacing.md),

                                // Distance Hero
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    distance,
                                    style: textTheme.headlineMedium?.copyWith(
                                      color: isTransparent
                                          ? overlayColor
                                          : colors.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: NearPaceSpacing.xs),

                                // Duration, Pace, and optional City row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ShareStatItem(
                                        label: 'TIME',
                                        value: duration,
                                        labelColor: isTransparent
                                            ? overlayColor.withValues(
                                                alpha: 0.72,
                                              )
                                            : colors.textMuted,
                                        valueColor: isTransparent
                                            ? overlayColor
                                            : colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: NearPaceSpacing.xs),
                                    Expanded(
                                      child: _ShareStatItem(
                                        label: 'AVG PACE',
                                        value: pace,
                                        labelColor: isTransparent
                                            ? overlayColor.withValues(
                                                alpha: 0.72,
                                              )
                                            : colors.textMuted,
                                        valueColor: isTransparent
                                            ? overlayColor
                                            : colors.textPrimary,
                                      ),
                                    ),
                                    if (activity.city != null &&
                                        activity.city!.trim().isNotEmpty) ...[
                                      const SizedBox(width: NearPaceSpacing.xs),
                                      Expanded(
                                        child: _ShareStatItem(
                                          label: 'CITY',
                                          value: activity.city!.trim(),
                                          labelColor: isTransparent
                                              ? overlayColor.withValues(
                                                  alpha: 0.72,
                                                )
                                              : colors.textMuted,
                                          valueColor: isTransparent
                                              ? overlayColor
                                              : colors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_statusNotice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NearPaceSpacing.md,
                NearPaceSpacing.xs,
                NearPaceSpacing.md,
                0,
              ),
              child: Text(
                _statusNotice!,
                style: textTheme.bodySmall?.copyWith(
                  color: _statusNotice!.contains('success')
                      ? colors.performanceGreen
                      : colors.warning,
                ),
              ),
            ),

          // Action buttons: Save Image and Share
          Padding(
            padding: EdgeInsets.fromLTRB(
              NearPaceSpacing.md,
              NearPaceSpacing.sm,
              NearPaceSpacing.md,
              MediaQuery.of(context).padding.bottom + NearPaceSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _isProcessing ? null : _saveToGallery,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: const Text('Save Image'),
                  ),
                ),
                const SizedBox(width: NearPaceSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onAccent,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          NearPaceSpacing.radiusMd,
                        ),
                      ),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share_rounded),
                    label: const Text(
                      'Share',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isProcessing ? null : _shareImage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStatItem extends StatelessWidget {
  const _ShareStatItem({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(
            color: labelColor,
            fontSize: 9,
            letterSpacing: 1.0,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Paints a subtle dark checkerboard exclusively behind the UI preview to
/// communicate PNG alpha transparency without affecting captured image bytes.
class _TransparencyCheckerboardPainter extends CustomPainter {
  const _TransparencyCheckerboardPainter();

  static const _tileSize = 12.0;
  static const _darkTile = Color(0xFF1A1F1C);
  static const _lightTile = Color(0xFF252C28);

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = _darkTile;
    final lightPaint = Paint()..color = _lightTile;

    final cols = (size.width / _tileSize).ceil();
    final rows = (size.height / _tileSize).ceil();

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final isEven = (row + col).isEven;
        canvas.drawRect(
          Rect.fromLTWH(col * _tileSize, row * _tileSize, _tileSize, _tileSize),
          isEven ? darkPaint : lightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TransparencyCheckerboardPainter oldDelegate) =>
      false;
}
