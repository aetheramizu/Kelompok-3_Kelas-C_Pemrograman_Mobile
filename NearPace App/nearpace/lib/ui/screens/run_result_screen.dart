import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/activity.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/metric_tile.dart';
import '../widgets/nearpace_card.dart';
import '../widgets/route_sketch.dart';
import '../widgets/weather_badge.dart';

/// Displays a completed or saved run with metrics, route sketch, and start-point
/// weather summary.
class RunResultScreen extends StatefulWidget {
  const RunResultScreen({
    super.key,
    required this.activity,
    this.isUnsaved = false,
  });

  final Activity activity;
  final bool isUnsaved;

  @override
  State<RunResultScreen> createState() => _RunResultScreenState();
}

class _RunResultScreenState extends State<RunResultScreen> {
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isPublic = true;
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    _isPublic = widget.activity.isPublic;
    _cityController = TextEditingController(text: widget.activity.city ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cityController.text.isEmpty) {
      final profCity = context.read<NearPaceController>().profile.city;
      if (profCity.trim().isNotEmpty) {
        _cityController.text = profCity.trim();
      }
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this run?'),
        content: const Text(
          'This recorded run has not been saved yet. Discarding removes its '
          'distance and route sketch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
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
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _confirmDeleteSaved() async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove run from history?'),
        content: const Text(
          'This removes the run from your history and updates this week\'s '
          'totals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.npColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (delete == true && mounted) {
      final controller = context.read<NearPaceController>();
      final messenger = ScaffoldMessenger.of(context);
      final nav = Navigator.of(context);
      setState(() => _isDeleting = true);
      try {
        await controller.deleteActivity(widget.activity.id);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              controller.isLocalPreview
                  ? 'Run removed from preview history.'
                  : 'Run removed from history.',
            ),
          ),
        );
        nav.pop();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isDeleting = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to delete run: $e')),
        );
      }
    }
  }

  Future<void> _saveRun() async {
    final controller = context.read<NearPaceController>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _isSaving = true);
    try {
      final cityInput = _cityController.text.trim();
      final effectiveCity = cityInput.isNotEmpty
          ? cityInput
          : (widget.activity.city ?? controller.profile.city);

      final activityToSave = widget.activity.copyWith(
        isPublic: _isPublic,
        city: effectiveCity,
      );

      await controller.saveActivity(activityToSave);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            controller.isLocalPreview
                ? (_isPublic
                      ? 'Run saved and posted to leaderboard.'
                      : 'Run saved privately to history.')
                : (_isPublic
                      ? 'Run saved and posted to $effectiveCity leaderboard!'
                      : 'Run saved privately to your history.'),
          ),
        ),
      );
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Saved locally on device (cloud sync failed: ${e.toString().split('\n').first})',
          ),
          action: SnackBarAction(label: 'Done', onPressed: () => nav.pop(true)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final isUnsaved = widget.isUnsaved;
    final activity = widget.activity;
    final title = NearPaceFormatters.runSessionTitle(activity.startedAt);
    final timestamp = NearPaceFormatters.activityTimestamp(activity.startedAt);
    final endedHh = activity.endedAt.toLocal().hour.toString().padLeft(2, '0');
    final endedMm = activity.endedAt.toLocal().minute.toString().padLeft(
      2,
      '0',
    );

    return PopScope(
      canPop: !isUnsaved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isUnsaved) {
          _confirmDiscard();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isUnsaved ? 'Run summary' : 'Activity detail'),
          leading: IconButton(
            tooltip: isUnsaved ? 'Discard run' : 'Back',
            onPressed: () {
              if (isUnsaved) {
                _confirmDiscard();
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: Icon(
              isUnsaved ? Icons.close_rounded : Icons.arrow_back_rounded,
            ),
          ),
          actions: [
            if (!isUnsaved)
              IconButton(
                tooltip: 'Remove run',
                onPressed: _isDeleting ? null : _confirmDeleteSaved,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.delete_outline_rounded, color: colors.danger),
              ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
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
                            NearPaceSpacing.xl,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: textTheme.headlineSmall?.copyWith(
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$timestamp • ended $endedHh:$endedMm',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: NearPaceSpacing.md),

                              Semantics(
                                label: 'Map of recorded run route',
                                child: NearPaceCard(
                                  padding: const EdgeInsets.all(
                                    NearPaceSpacing.sm,
                                  ),
                                  child: RouteSketch(
                                    route: activity.route,
                                    height: 200,
                                  ),
                                ),
                              ),

                              const SizedBox(height: NearPaceSpacing.md),

                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: NearPaceCard(
                                        padding: const EdgeInsets.all(
                                          NearPaceSpacing.md,
                                        ),
                                        child: MetricTile(
                                          label: 'Distance',
                                          value:
                                              NearPaceFormatters.distanceKmValue(
                                                activity.distanceM,
                                              ),
                                          unit: 'km',
                                          icon: Icons.straighten_rounded,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: NearPaceSpacing.sm),
                                    Expanded(
                                      child: NearPaceCard(
                                        padding: const EdgeInsets.all(
                                          NearPaceSpacing.md,
                                        ),
                                        child: MetricTile(
                                          label: 'Duration',
                                          value:
                                              NearPaceFormatters.durationClock(
                                                activity.duration,
                                              ),
                                          icon: Icons.timer_outlined,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: NearPaceSpacing.sm),

                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: NearPaceCard(
                                        padding: const EdgeInsets.all(
                                          NearPaceSpacing.md,
                                        ),
                                        child: MetricTile(
                                          label: 'Avg pace',
                                          value: NearPaceFormatters.paceValue(
                                            activity.avgPaceSecPerKm,
                                          ),
                                          unit: '/km',
                                          icon: Icons.speed_rounded,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: NearPaceSpacing.sm),
                                    Expanded(
                                      child: NearPaceCard(
                                        padding: const EdgeInsets.all(
                                          NearPaceSpacing.md,
                                        ),
                                        child: MetricTile(
                                          label: 'GPS points',
                                          value: '${activity.route.length}',
                                          unit: 'pts',
                                          icon: Icons.gps_fixed_rounded,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (activity.avgPaceSecPerKm == null) ...[
                                const SizedBox(height: NearPaceSpacing.sm),
                                Text(
                                  'Average pace requires at least 50 m of '
                                  'recorded distance.',
                                  style: textTheme.bodySmall,
                                ),
                              ],

                              const SizedBox(height: NearPaceSpacing.lg),
                              Text(
                                'Start-point weather',
                                style: textTheme.titleMedium,
                              ),
                              const SizedBox(height: NearPaceSpacing.xs),
                              WeatherSummaryCard(weather: activity.weather),

                              if (isUnsaved) ...[
                                const SizedBox(height: NearPaceSpacing.lg),
                                Text(
                                  'Visibilitas & Leaderboard',
                                  style: textTheme.titleMedium,
                                ),
                                const SizedBox(height: NearPaceSpacing.xs),
                                NearPaceCard(
                                  padding: const EdgeInsets.all(
                                    NearPaceSpacing.md,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _isPublic
                                                ? Icons.public_rounded
                                                : Icons.lock_outline_rounded,
                                            color: _isPublic
                                                ? colors.performanceGreen
                                                : colors.textSecondary,
                                            size: 20,
                                          ),
                                          const SizedBox(
                                            width: NearPaceSpacing.xs,
                                          ),
                                          Expanded(
                                            child: Text(
                                              _isPublic
                                                  ? 'Post ke Leaderboard Publik'
                                                  : 'Privat (Hanya Saya)',
                                              style: textTheme.titleSmall,
                                            ),
                                          ),
                                          Switch(
                                            value: _isPublic,
                                            onChanged: (val) {
                                              setState(() => _isPublic = val);
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                        height: NearPaceSpacing.xxs,
                                      ),
                                      Text(
                                        _isPublic
                                            ? 'Jarak lari ini akan diposting ke papan peringkat kota Anda.'
                                            : 'Lari ini disimpan secara privat dan tidak akan muncul di leaderboard publik.',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                      if (_isPublic) ...[
                                        const SizedBox(
                                          height: NearPaceSpacing.md,
                                        ),
                                        TextFormField(
                                          controller: _cityController,
                                          decoration: InputDecoration(
                                            labelText: 'Kota Daerah Lari (Leaderboard)',
                                            hintText: 'e.g. Makassar, Jakarta, Surabaya',
                                            isDense: true,
                                            prefixIcon: const Icon(
                                              Icons.location_city_rounded,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (isUnsaved)
                        SafeArea(
                          top: false,
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              NearPaceSpacing.sm,
                              gutter,
                              NearPaceSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              border: Border(
                                top: BorderSide(color: colors.border),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context
                                          .read<NearPaceController>()
                                          .isLocalPreview
                                      ? 'Run will be saved to your local history.'
                                      : 'Run will be saved to your account and synced to Firestore.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: NearPaceSpacing.sm),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _isSaving ? null : _saveRun,
                                    icon: _isSaving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.check_rounded),
                                    label: Text(
                                      _isSaving ? 'Saving run...' : 'Save run',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: NearPaceSpacing.xs),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed: _isSaving
                                        ? null
                                        : _confirmDiscard,
                                    style: TextButton.styleFrom(
                                      foregroundColor: colors.danger,
                                    ),
                                    child: const Text('Discard run'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
