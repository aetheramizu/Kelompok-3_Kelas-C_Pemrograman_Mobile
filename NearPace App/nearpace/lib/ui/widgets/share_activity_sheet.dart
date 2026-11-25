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
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
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
      final text = 'Ran $distanceKm with NearPace (avg pace $pace)! 🏃‍♂️⚡';

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

          // Mode & Tone Switchers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NearPaceSpacing.md),
            child: Row(
              children: [
                // Mode Toggle
                Expanded(
                  child: SegmentedButton<ShareCardMode>(
                    segments: const [
                      ButtonSegment(
                        value: ShareCardMode.transparentSticker,
                        label: Text(
                          'Transparent Sticker',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      ButtonSegment(
                        value: ShareCardMode.darkBrandCard,
                        label: Text(
                          'Dark Brand Card',
                          style: TextStyle(fontSize: 11),
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
                    selectedColor: colors.accent,
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
                    selectedColor: const Color(0xFFF2F5F0),
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

          // Card preview viewport
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.md,
              ),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    // Checkerboard in UI preview only when transparent
                    color: isTransparent
                        ? const Color(0xFF1E2320)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      NearPaceSpacing.radiusMd,
                    ),
                    border: Border.all(color: colors.border),
                  ),
                  padding: const EdgeInsets.all(NearPaceSpacing.md),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: Container(
                      width: 280,
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
                            : Border.all(color: colors.border, width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Branding header
                          Row(
                            children: [
                              NearPaceLogo(
                                size: 28,
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
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                date,
                                style: textTheme.bodySmall?.copyWith(
                                  color: isTransparent
                                      ? overlayColor.withValues(alpha: 0.8)
                                      : colors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: NearPaceSpacing.md),

                          // Route sketch
                          Center(
                            child: SizedBox(
                              width: 220,
                              height: 140,
                              child: RouteSketch(
                                route: activity.route,
                                showGrid: !isTransparent,
                                compact: true,
                              ),
                            ),
                          ),

                          const SizedBox(height: NearPaceSpacing.md),

                          // Distance Hero
                          Text(
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

                          const SizedBox(height: NearPaceSpacing.xs),

                          // Duration & Pace row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TIME',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: isTransparent
                                          ? overlayColor.withValues(alpha: 0.7)
                                          : colors.textMuted,
                                      fontSize: 9,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Text(
                                    duration,
                                    style: textTheme.titleSmall?.copyWith(
                                      color: isTransparent
                                          ? overlayColor
                                          : colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AVG PACE',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: isTransparent
                                          ? overlayColor.withValues(alpha: 0.7)
                                          : colors.textMuted,
                                      fontSize: 9,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Text(
                                    pace,
                                    style: textTheme.titleSmall?.copyWith(
                                      color: isTransparent
                                          ? overlayColor
                                          : colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              if (activity.city != null &&
                                  activity.city!.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CITY',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: isTransparent
                                            ? overlayColor.withValues(
                                                alpha: 0.7,
                                              )
                                            : colors.textMuted,
                                        fontSize: 9,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Text(
                                      activity.city!,
                                      style: textTheme.titleSmall?.copyWith(
                                        color: isTransparent
                                            ? overlayColor
                                            : colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
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

          if (_statusNotice != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.md,
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
              NearPaceSpacing.xs,
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
