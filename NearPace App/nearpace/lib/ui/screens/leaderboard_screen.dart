import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/leaderboard_entry.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/nearpace_card.dart';
import '../widgets/state_views.dart';

/// Weekly distance leaderboard built from public opt-in aggregates, filterable
/// by city. Private fields (email, GPS routes) are never shown.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final profile = controller.profile;
    final entries = controller.filteredLeaderboardEntries;
    final cities = controller.availableCities;
    final selectedCity = controller.selectedCity;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = NearPaceSpacing.pageGutter(constraints.maxWidth);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: NearPaceSpacing.maxContentWidth,
            ),
            child: CustomScrollView(
              key: const ValueKey('leaderboard-scroll'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    NearPaceSpacing.md,
                    gutter,
                    NearPaceSpacing.sm,
                  ),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Leaderboard',
                                  style: textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Weekly distance · '
                                  '${NearPaceFormatters.weekRangeLabel(controller.now)}',
                                  style: textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: profile.showOnLeaderboard
                                ? 'Opted in'
                                : 'Private',
                            icon: profile.showOnLeaderboard
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            foregroundColor: profile.showOnLeaderboard
                                ? colors.performanceGreen
                                : colors.textSecondary,
                            backgroundColor: profile.showOnLeaderboard
                                ? colors.deepGreenSurface
                                : colors.surfaceElevated,
                            onTap: () => controller.setTabIndex(3),
                          ),
                        ],
                      ),
                      const SizedBox(height: NearPaceSpacing.md),

                      // Opt-in privacy prompt when runner is currently hidden.
                      if (!profile.showOnLeaderboard) ...[
                        NearPaceCard(
                          elevated: true,
                          padding: const EdgeInsets.all(NearPaceSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colors.deepGreenSurface,
                                  borderRadius: BorderRadius.circular(
                                    NearPaceSpacing.radiusSm,
                                  ),
                                ),
                                child: Icon(
                                  Icons.shield_outlined,
                                  size: 20,
                                  color: colors.performanceGreen,
                                ),
                              ),
                              const SizedBox(width: NearPaceSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your profile is private',
                                      style: textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Opt in to share only your display name, '
                                      'city, and weekly distance.',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: NearPaceSpacing.xs),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                                onPressed: () =>
                                    controller.setShowOnLeaderboard(true),
                                child: const Text('Opt in'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: NearPaceSpacing.md),
                      ],

                      // City filter bar.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CityChip(
                              label: 'All cities',
                              selected: selectedCity == null,
                              onTap: () => controller.setSelectedCity(null),
                            ),
                            ...cities.map(
                              (city) => Padding(
                                padding: const EdgeInsets.only(
                                  left: NearPaceSpacing.xs,
                                ),
                                child: _CityChip(
                                  label: city,
                                  selected: selectedCity == city,
                                  onTap: () => controller.setSelectedCity(city),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main ranked content.
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    NearPaceSpacing.xs,
                    gutter,
                    NearPaceSpacing.xxxl,
                  ),
                  sliver: switch (controller.leaderboardState) {
                    ViewLoadState.loading => const SliverToBoxAdapter(
                      child: LoadingSkeletonList(itemCount: 4),
                    ),
                    ViewLoadState.error => SliverToBoxAdapter(
                      child: ErrorStateView(
                        title: 'Could not load leaderboard',
                        message:
                            controller.leaderboardError ??
                            'Unable to load this week\'s rankings right now.',
                        onRetry: controller.retryLeaderboard,
                      ),
                    ),
                    ViewLoadState.ready when entries.isEmpty =>
                      SliverToBoxAdapter(
                        child: EmptyStateView(
                          icon: Icons.leaderboard_outlined,
                          title: selectedCity == null
                              ? 'No runners on this week\'s board'
                              : 'No runners in $selectedCity yet',
                          message: selectedCity == null
                              ? 'Opt in from Profile and save a run to appear '
                                    'on the weekly leaderboard.'
                              : 'No opted-in runners have logged distance in '
                                    '$selectedCity this week.',
                          actionLabel: selectedCity == null
                              ? (profile.showOnLeaderboard
                                    ? null
                                    : 'Opt in now')
                              : 'Show all cities',
                          onAction: selectedCity == null
                              ? (profile.showOnLeaderboard
                                    ? null
                                    : () =>
                                          controller.setShowOnLeaderboard(true))
                              : () => controller.setSelectedCity(null),
                        ),
                      ),
                    ViewLoadState.ready => SliverList.list(
                      children: [
                        if (entries.length >= 2) ...[
                          _TopRunnersStrip(
                            topEntries: entries.take(3).toList(growable: false),
                            currentUid: profile.uid,
                          ),
                          const SizedBox(height: NearPaceSpacing.md),
                        ],
                        ...List.generate(entries.length, (index) {
                          final entry = entries[index];
                          final isCurrentUser = entry.uid == profile.uid;
                          return Padding(
                            key: ValueKey(entry.documentId),
                            padding: EdgeInsets.only(
                              bottom: index == entries.length - 1
                                  ? 0
                                  : NearPaceSpacing.xs,
                            ),
                            child: _LeaderboardRow(
                              rank: index + 1,
                              entry: entry,
                              isCurrentUser: isCurrentUser,
                            ),
                          );
                        }),
                      ],
                    ),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CityChip extends StatelessWidget {
  const _CityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? colors.onAccent : colors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        fontSize: 13,
      ),
      selectedColor: colors.accent,
      backgroundColor: colors.surface,
      side: BorderSide(color: selected ? colors.accent : colors.border),
      onSelected: (_) => onTap(),
    );
  }
}

class _TopRunnersStrip extends StatelessWidget {
  const _TopRunnersStrip({required this.topEntries, required this.currentUid});

  final List<LeaderboardEntry> topEntries;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(topEntries.length, (index) {
        final entry = topEntries[index];
        final isFirst = index == 0;
        final isMe = entry.uid == currentUid;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 4,
              right: index == topEntries.length - 1 ? 0 : 4,
            ),
            child: NearPaceCard(
              backgroundColor: isFirst
                  ? colors.deepGreenSurface
                  : colors.surface,
              borderColor: isFirst
                  ? colors.accent.withValues(alpha: 0.6)
                  : (isMe ? colors.accentText : colors.border),
              padding: EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.sm,
                vertical: isFirst ? NearPaceSpacing.md : NearPaceSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isFirst ? colors.accent : colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(
                        NearPaceSpacing.radiusPill,
                      ),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: textTheme.labelSmall?.copyWith(
                        color: isFirst ? colors.onAccent : colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: NearPaceSpacing.xs),
                  CircleAvatar(
                    radius: isFirst ? 20 : 17,
                    backgroundColor: colors.surfaceElevated,
                    child: Text(
                      entry.initials,
                      style: textTheme.labelMedium?.copyWith(
                        color: isFirst ? colors.accentText : colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: NearPaceSpacing.xs),
                  Text(
                    entry.displayName.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      NearPaceFormatters.distanceKm(
                        entry.distanceM,
                        decimals: 1,
                      ),
                      maxLines: 1,
                      style: textTheme.titleSmall?.copyWith(
                        color: isFirst ? colors.accentText : colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    entry.city.isEmpty ? 'No city' : entry.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label:
          'Rank $rank, ${entry.displayName}${isCurrentUser ? ' (You)' : ''}, '
          '${entry.city}, ${NearPaceFormatters.distanceKm(entry.distanceM, decimals: 1)}',
      child: NearPaceCard(
        backgroundColor: isCurrentUser
            ? colors.deepGreenSurface
            : colors.surface,
        borderColor: isCurrentUser
            ? colors.accentText.withValues(alpha: 0.6)
            : colors.border,
        padding: const EdgeInsets.symmetric(
          horizontal: NearPaceSpacing.md,
          vertical: NearPaceSpacing.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: textTheme.titleMedium?.copyWith(
                  color: rank <= 3 ? colors.accentText : colors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.surfaceElevated,
              child: Text(
                entry.initials,
                style: textTheme.labelMedium?.copyWith(
                  color: colors.textPrimary,
                ),
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
                          entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(
                              NearPaceSpacing.radiusPill,
                            ),
                          ),
                          child: Text(
                            'You',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onAccent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.city.isEmpty ? 'No city set' : entry.city} · '
                    '${entry.runCount} ${entry.runCount == 1 ? 'run' : 'runs'}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NearPaceSpacing.sm),
            Text(
              NearPaceFormatters.distanceKm(entry.distanceM, decimals: 1),
              style: textTheme.titleMedium?.copyWith(
                color: isCurrentUser ? colors.accentText : colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
