import 'package:material_ui/material_ui.dart';

import '../../domain/weather.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import 'nearpace_card.dart';

/// Maps Open-Meteo WMO weather codes to a consistent Material icon.
IconData weatherIconForCode(int? code) {
  if (code == null) return Icons.cloud_off_rounded;
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code <= 2) return Icons.wb_cloudy_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.grain_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 86) return Icons.umbrella_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  return Icons.cloud_queue_rounded;
}

/// Compact inline weather chip shown on activity list items.
class WeatherPill extends StatelessWidget {
  const WeatherPill({super.key, required this.weather});

  final WeatherSnapshot? weather;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final snapshot = weather;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(NearPaceSpacing.radiusPill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              weatherIconForCode(snapshot.code),
              size: 13,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${snapshot.temperatureC.round()}°C',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full weather summary card for the Run Result screen, including
/// Open-Meteo attribution and graceful offline fallback.
class WeatherSummaryCard extends StatelessWidget {
  const WeatherSummaryCard({
    super.key,
    required this.weather,
    this.isLoading = false,
  });

  final WeatherSnapshot? weather;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    if (isLoading) {
      return NearPaceCard(
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accentText,
              ),
            ),
            const SizedBox(width: NearPaceSpacing.sm),
            Expanded(
              child: Text(
                'Loading start-point conditions...',
                style: textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final snapshot = weather;
    if (snapshot == null) {
      return NearPaceCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 20,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(width: NearPaceSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Conditions unavailable', style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Weather could not be loaded for this run. Saved metrics '
                    'are unaffected.',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return NearPaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.deepGreenSurface,
                  borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
                ),
                child: Icon(
                  weatherIconForCode(snapshot.code),
                  size: 22,
                  color: colors.performanceGreen,
                ),
              ),
              const SizedBox(width: NearPaceSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            snapshot.label,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        if (snapshot.isCachedForecast) ...[
                          const SizedBox(width: NearPaceSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceElevated,
                              borderRadius: BorderRadius.circular(
                                NearPaceSpacing.radiusPill,
                              ),
                              border: Border.all(color: colors.border),
                            ),
                            child: Text(
                              'Cached forecast',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Feels like ${snapshot.apparentC.toStringAsFixed(1)}°C '
                      'at start point',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                flex: 0,
                child: Text(
                  '${snapshot.temperatureC.toStringAsFixed(1)}°C',
                  style: textTheme.headlineMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NearPaceSpacing.sm),
          Divider(color: colors.border),
          const SizedBox(height: NearPaceSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weather data by Open-Meteo',
                style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
              if (snapshot.isCachedForecast)
                Text(
                  'Layer 1 Offline Cache',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.accentText,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
