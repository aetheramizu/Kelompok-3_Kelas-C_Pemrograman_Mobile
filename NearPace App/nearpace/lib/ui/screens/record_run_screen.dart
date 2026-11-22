import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/run_state.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/location_permission_sheet.dart';
import '../widgets/metric_tile.dart';
import '../widgets/nearpace_card.dart';
import '../widgets/route_sketch.dart';
import '../widgets/state_views.dart';
import 'run_result_screen.dart';

/// Full-screen foreground run recording experience covering every sealed
/// [RunState] transition (`RunIdle`, `RunPreparing`, `RunActive`,
/// `RunStopping`, `RunFailed`) plus foreground location permissions.
class RecordRunScreen extends StatefulWidget {
  const RecordRunScreen({super.key});

  @override
  State<RecordRunScreen> createState() => _RecordRunScreenState();
}

class _RecordRunScreenState extends State<RecordRunScreen> {
  Future<void> _handleStartTap(NearPaceController controller) async {
    if (controller.locationPermission != LocationPermissionStatus.granted) {
      final result = await showLocationPermissionSheet(
        context,
        currentStatus: controller.locationPermission,
        isLocalPreview: controller.isLocalPreview,
      );
      if (!mounted || result == null) return;
      controller.setLocationPermission(result);
      if (result != LocationPermissionStatus.granted) return;
    }
    await controller.startRecording();
  }

  Future<void> _openPermissionSheet(NearPaceController controller) async {
    final result = await showLocationPermissionSheet(
      context,
      currentStatus: controller.locationPermission,
      isLocalPreview: controller.isLocalPreview,
    );
    if (!mounted || result == null) return;
    controller.setLocationPermission(result);
  }

  Future<void> _handleFinish(NearPaceController controller) async {
    final activity = await controller.finishRecording();
    if (!mounted || activity == null) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RunResultScreen(activity: activity, isUnsaved: true),
      ),
    );
  }

  Future<void> _confirmFinish(NearPaceController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish this run?'),
        content: const Text(
          'Stop recording and review your distance, pace, route sketch, and '
          'weather summary before saving.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep running'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finish run'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _handleFinish(controller);
    }
  }

  Future<void> _confirmDiscardAndLeave(NearPaceController controller) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard active run?'),
        content: const Text(
          'Leaving now will stop recording and discard the current session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep running'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.npColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      controller.resetRecording();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();
    final colors = context.npColors;
    final runState = controller.runState;
    final isGuarded = runState is RunActive || runState is RunPreparing;

    return PopScope(
      canPop: !isGuarded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isGuarded) {
          _confirmDiscardAndLeave(controller);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (runState) {
            RunIdle() => 'Record run',
            RunPreparing() => 'Acquiring GPS',
            RunActive(paused: false) => 'Running',
            RunActive(paused: true) => 'Paused',
            RunStopping() => 'Finishing',
            RunFailed() => 'GPS unavailable',
          }),
          leading: IconButton(
            tooltip: isGuarded ? 'Discard and close' : 'Close',
            onPressed: () {
              if (isGuarded) {
                _confirmDiscardAndLeave(controller);
              } else {
                controller.resetRecording();
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.close_rounded),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: NearPaceSpacing.sm),
              child: _GpsHeaderBadge(
                runState: runState,
                permission: controller.locationPermission,
                onTap: runState is RunIdle || runState is RunFailed
                    ? () => _openPermissionSheet(controller)
                    : null,
              ),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = NearPaceSpacing.pageGutter(constraints.maxWidth);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: NearPaceSpacing.maxContentWidth,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          NearPaceSpacing.sm,
                          gutter,
                          NearPaceSpacing.lg,
                        ),
                        child: AnimatedSwitcher(
                          duration: NearPaceMotion.resolve(
                            context,
                            NearPaceMotion.standard,
                          ),
                          switchInCurve: NearPaceMotion.easeOut,
                          child: switch (runState) {
                            RunIdle() => _IdleBody(
                              controller: controller,
                              onRequestPermission: () =>
                                  _openPermissionSheet(controller),
                            ),
                            RunPreparing() => _PreparingBody(
                              isLocalPreview: controller.isLocalPreview,
                              onSimulateLoss: controller.simulateGpsSignalLost,
                            ),
                            RunActive(:final paused) => _ActiveBody(
                              controller: controller,
                              paused: paused,
                            ),
                            RunStopping() => const _StoppingBody(),
                            RunFailed(:final message) => _FailedBody(
                              message: message,
                              onCheckPermission: () =>
                                  _openPermissionSheet(controller),
                              onRetry: () => _handleStartTap(controller),
                            ),
                          },
                        ),
                      ),
                    ),
                    _RecordingControlsDock(
                      gutter: gutter,
                      runState: runState,
                      backgroundColor: colors.surface,
                      borderColor: colors.border,
                      onStart: () => _handleStartTap(controller),
                      onCancelPreparing: controller.resetRecording,
                      onPause: controller.pauseRecording,
                      onResume: controller.resumeRecording,
                      onFinish: () => _confirmFinish(controller),
                      onDiscard: () => _confirmDiscardAndLeave(controller),
                      onRetry: () => _handleStartTap(controller),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GpsHeaderBadge extends StatelessWidget {
  const _GpsHeaderBadge({
    required this.runState,
    required this.permission,
    this.onTap,
  });

  final RunState runState;
  final LocationPermissionStatus permission;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final (label, icon, fg, bg) = switch (runState) {
      RunActive(paused: false) => (
        'GPS active',
        Icons.gps_fixed_rounded,
        colors.performanceGreen,
        colors.deepGreenSurface,
      ),
      RunActive(paused: true) => (
        'Paused',
        Icons.pause_circle_outline_rounded,
        colors.warning,
        colors.warningSurface,
      ),
      RunPreparing() => (
        'Locking GPS',
        Icons.gps_not_fixed_rounded,
        colors.warning,
        colors.warningSurface,
      ),
      RunStopping() => (
        'Finalizing',
        Icons.hourglass_top_rounded,
        colors.textSecondary,
        colors.surfaceElevated,
      ),
      RunFailed() => (
        'GPS blocked',
        Icons.gps_off_rounded,
        colors.danger,
        colors.dangerSurface,
      ),
      RunIdle() => switch (permission) {
        LocationPermissionStatus.granted => (
          'GPS ready',
          Icons.gps_fixed_rounded,
          colors.performanceGreen,
          colors.deepGreenSurface,
        ),
        LocationPermissionStatus.denied ||
        LocationPermissionStatus.deniedForever => (
          'Permission off',
          Icons.location_off_rounded,
          colors.danger,
          colors.dangerSurface,
        ),
        LocationPermissionStatus.notRequested => (
          'Location needed',
          Icons.my_location_rounded,
          colors.textSecondary,
          colors.surfaceElevated,
        ),
      },
    };

    return StatusPill(
      label: label,
      icon: icon,
      foregroundColor: fg,
      backgroundColor: bg,
      borderColor: fg.withValues(alpha: 0.35),
      onTap: onTap,
    );
  }
}

class _IdleBody extends StatelessWidget {
  const _IdleBody({
    required this.controller,
    required this.onRequestPermission,
  });

  final NearPaceController controller;
  final VoidCallback onRequestPermission;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: const ValueKey('run-idle'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RouteSketch(
          route: [],
          height: 220,
          emptyMessage:
              'Press Start to acquire a foreground GPS fix and draw '
              'your route sketch.',
        ),
        const SizedBox(height: NearPaceSpacing.lg),
        NearPaceCard(
          child: Row(
            children: [
              const Expanded(
                child: MetricTile(
                  label: 'Duration',
                  value: '00:00',
                  compact: true,
                ),
              ),
              Container(width: 1, height: 42, color: colors.border),
              const SizedBox(width: NearPaceSpacing.md),
              const Expanded(
                child: MetricTile(
                  label: 'Distance',
                  value: '0.00',
                  unit: 'km',
                  compact: true,
                ),
              ),
              Container(width: 1, height: 42, color: colors.border),
              const SizedBox(width: NearPaceSpacing.md),
              const Expanded(
                child: MetricTile(label: 'Pace', value: '--:--', compact: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: NearPaceSpacing.md),
        if (controller.isLocalPreview) ...[
          NearPaceCard(
            elevated: true,
            padding: const EdgeInsets.all(NearPaceSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: NearPaceSpacing.xs),
                    Expanded(
                      child: Text(
                        'Preview session options',
                        style: textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NearPaceSpacing.xs),
                Text(
                  'Local preview options for testing GPS tracking and offline '
                  'weather states.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: NearPaceSpacing.xs),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Simulate GPS route points',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Feeds realistic coordinates into RunSession every 3 seconds',
                    style: textTheme.bodySmall,
                  ),
                  value: controller.simulateGpsInPreview,
                  onChanged: controller.setSimulateGpsInPreview,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Include Open-Meteo weather snapshot',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Turn off to preview the offline weather fallback on summary',
                    style: textTheme.bodySmall,
                  ),
                  value: controller.weatherAvailableInPreview,
                  onChanged: controller.setWeatherAvailableInPreview,
                ),
                const SizedBox(height: NearPaceSpacing.xs),
                OutlinedButton.icon(
                  onPressed: onRequestPermission,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Review location permission'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PreparingBody extends StatelessWidget {
  const _PreparingBody({
    required this.onSimulateLoss,
    this.isLocalPreview = true,
  });

  final VoidCallback onSimulateLoss;
  final bool isLocalPreview;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    return NearPaceCard(
      key: const ValueKey('run-preparing'),
      padding: const EdgeInsets.symmetric(
        horizontal: NearPaceSpacing.xl,
        vertical: NearPaceSpacing.xxl,
      ),
      child: Column(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              color: colors.accentText,
            ),
          ),
          const SizedBox(height: NearPaceSpacing.lg),
          Text(
            'Acquiring GPS signal',
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NearPaceSpacing.xs),
          Text(
            'Waiting for an accurate foreground fix before starting the timer.',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (isLocalPreview) ...[
            const SizedBox(height: NearPaceSpacing.lg),
            TextButton(
              onPressed: onSimulateLoss,
              child: const Text('Simulate GPS failure'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveBody extends StatelessWidget {
  const _ActiveBody({required this.controller, required this.paused});

  final NearPaceController controller;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final session = controller.activeSession;
    final now = DateTime.now();
    final elapsed = session?.elapsedAt(now) ?? Duration.zero;
    final distanceM = session?.distanceMeters ?? 0;
    final pace = session?.paceSecPerKmAt(now);
    final route = session?.route ?? const [];

    return Column(
      key: const ValueKey('run-active'),
      children: [
        RouteSketch(
          route: route,
          height: 200,
          isLive: !paused,
          emptyMessage: paused
              ? 'Run paused. Resume to continue recording route points.'
              : 'Collecting GPS points for your route sketch...',
        ),
        const SizedBox(height: NearPaceSpacing.lg),

        // Oversized tabular Duration hero readout (Strava / reference pattern).
        Text(
          'DURATION',
          style: textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: NearPaceSpacing.xxs),
        Semantics(
          liveRegion: true,
          label: 'Elapsed time ${NearPaceFormatters.durationClock(elapsed)}',
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              NearPaceFormatters.durationClock(elapsed),
              maxLines: 1,
              style: textTheme.displayLarge?.copyWith(
                color: paused ? colors.textSecondary : colors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: NearPaceSpacing.lg),

        // Distance & Pace split panel.
        Row(
          children: [
            Expanded(
              child: NearPaceCard(
                padding: const EdgeInsets.all(NearPaceSpacing.md),
                child: MetricTile(
                  label: 'Distance',
                  value: NearPaceFormatters.distanceKmValue(distanceM),
                  unit: 'km',
                  highlight: !paused,
                  crossAxisAlignment: CrossAxisAlignment.center,
                ),
              ),
            ),
            const SizedBox(width: NearPaceSpacing.sm),
            Expanded(
              child: NearPaceCard(
                padding: const EdgeInsets.all(NearPaceSpacing.md),
                child: MetricTile(
                  label: 'Avg pace',
                  value: NearPaceFormatters.paceValue(pace),
                  unit: '/km',
                  crossAxisAlignment: CrossAxisAlignment.center,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: NearPaceSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.satellite_alt_rounded,
              size: 14,
              color: colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              '${session?.acceptedSamples ?? 0} accepted fixes'
              '${(session?.rejectedSamples ?? 0) > 0 ? ' • ${session!.rejectedSamples} filtered' : ''}',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _StoppingBody extends StatelessWidget {
  const _StoppingBody();

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    return NearPaceCard(
      key: const ValueKey('run-stopping'),
      padding: const EdgeInsets.all(NearPaceSpacing.xxl),
      child: Column(
        children: [
          CircularProgressIndicator(strokeWidth: 3, color: colors.accentText),
          const SizedBox(height: NearPaceSpacing.md),
          Text(
            'Preparing your run summary...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _FailedBody extends StatelessWidget {
  const _FailedBody({
    required this.message,
    required this.onCheckPermission,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onCheckPermission;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('run-failed'),
      children: [
        ErrorStateView(
          title: 'Cannot start recording',
          message: message,
          onRetry: onRetry,
        ),
        const SizedBox(height: NearPaceSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCheckPermission,
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Update location permission'),
          ),
        ),
      ],
    );
  }
}

class _RecordingControlsDock extends StatelessWidget {
  const _RecordingControlsDock({
    required this.gutter,
    required this.runState,
    required this.backgroundColor,
    required this.borderColor,
    required this.onStart,
    required this.onCancelPreparing,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onDiscard,
    required this.onRetry,
  });

  final double gutter;
  final RunState runState;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onStart;
  final VoidCallback onCancelPreparing;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onDiscard;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          gutter,
          NearPaceSpacing.md,
          gutter,
          NearPaceSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: switch (runState) {
          RunIdle() => Center(
            child: _CircularControlButton(
              size: 80,
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              icon: Icons.play_arrow_rounded,
              iconSize: 40,
              label: 'Start run',
              onTap: onStart,
            ),
          ),
          RunPreparing() => Center(
            child: OutlinedButton(
              onPressed: onCancelPreparing,
              child: const Text('Cancel'),
            ),
          ),
          RunActive(paused: false) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CircularControlButton(
                size: 56,
                backgroundColor: colors.surfaceElevated,
                foregroundColor: colors.textSecondary,
                borderColor: colors.border,
                icon: Icons.delete_outline_rounded,
                iconSize: 24,
                label: 'Discard',
                onTap: onDiscard,
              ),
              _CircularControlButton(
                size: 80,
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
                icon: Icons.pause_rounded,
                iconSize: 38,
                label: 'Pause',
                onTap: onPause,
              ),
              _CircularControlButton(
                size: 56,
                backgroundColor: colors.surfaceElevated,
                foregroundColor: colors.textPrimary,
                borderColor: colors.border,
                icon: Icons.stop_rounded,
                iconSize: 26,
                label: 'Finish',
                onTap: onFinish,
              ),
            ],
          ),
          RunActive(paused: true) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CircularControlButton(
                size: 56,
                backgroundColor: colors.dangerSurface,
                foregroundColor: colors.danger,
                borderColor: colors.danger.withValues(alpha: 0.4),
                icon: Icons.delete_outline_rounded,
                iconSize: 24,
                label: 'Discard',
                onTap: onDiscard,
              ),
              _CircularControlButton(
                size: 80,
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
                icon: Icons.play_arrow_rounded,
                iconSize: 40,
                label: 'Resume',
                onTap: onResume,
              ),
              _CircularControlButton(
                size: 56,
                backgroundColor: colors.surfaceElevated,
                foregroundColor: colors.textPrimary,
                borderColor: colors.border,
                icon: Icons.flag_rounded,
                iconSize: 24,
                label: 'Finish',
                onTap: onFinish,
              ),
            ],
          ),
          RunStopping() => const SizedBox(height: 56),
          RunFailed() => SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRetry,
              child: const Text('Try starting run again'),
            ),
          ),
        },
      ),
    );
  }
}

class _CircularControlButton extends StatelessWidget {
  const _CircularControlButton({
    required this.size,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.onTap,
    this.borderColor,
  });

  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final IconData icon;
  final double iconSize;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: backgroundColor,
            shape: CircleBorder(
              side: borderColor == null
                  ? BorderSide.none
                  : BorderSide(color: borderColor!),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, size: iconSize, color: foregroundColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
