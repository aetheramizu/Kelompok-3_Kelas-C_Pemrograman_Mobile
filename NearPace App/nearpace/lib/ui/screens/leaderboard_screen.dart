import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/leaderboard_entry.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/nearpace_avatar.dart';
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
    final selectedCity = controller.selectedCity;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = NearPaceSpacing.pageGutter(constraints.maxWidth);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: NearPaceSpacing.maxContentWidth,
            ),
            child: RefreshIndicator(
              onRefresh: controller.refreshLeaderboard,
              child: CustomScrollView(
                key: const ValueKey('leaderboard-scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
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
                        if (controller.isOffline) ...[
                          const SizedBox(height: NearPaceSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: NearPaceSpacing.sm,
                              vertical: NearPaceSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: colors.warningSurface,
                              borderRadius: BorderRadius.circular(
                                NearPaceSpacing.radiusSm,
                              ),
                              border: Border.all(
                                color: colors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cloud_off_rounded,
                                  size: 16,
                                  color: colors.warning,
                                ),
                                const SizedBox(width: NearPaceSpacing.xs),
                                Expanded(
                                  child: Text(
                                    'Offline — showing cached leaderboard standings.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Join this week\'s leaderboard',
                                        style: textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Share your name, city, and weekly '
                                        'distance to see your rank. Your routes '
                                        'stay private.',
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
                                  child: const Text('Join'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: NearPaceSpacing.md),
                        ],

                        // Compact City Selector Pill
                        Row(
                          children: [
                            _CitySelectorPill(
                              selectedCity: selectedCity,
                              runnerCount: entries.length,
                              onTap: () {
                                _showCitySearchSheet(
                                  context,
                                  controller: controller,
                                  userCity: profile.city,
                                );
                              },
                            ),
                          ],
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
                                ? 'Join the leaderboard and log a run to '
                                      'appear here.'
                                : 'No runners in $selectedCity have logged a '
                                      'run this week yet.',
                            actionLabel: selectedCity == null
                                ? (profile.showOnLeaderboard
                                      ? null
                                      : 'Join leaderboard')
                                : 'Show all cities',
                            onAction: selectedCity == null
                                ? (profile.showOnLeaderboard
                                      ? null
                                      : () => controller.setShowOnLeaderboard(
                                          true,
                                        ))
                                : () => controller.setSelectedCity(null),
                          ),
                        ),
                      ViewLoadState.ready => SliverList.list(
                        children: [
                          if (entries.length >= 2) ...[
                            _TopRunnersStrip(
                              topEntries: entries
                                  .take(3)
                                  .toList(growable: false),
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
          ),
        );
      },
    );
  }
}

class _CitySelectorPill extends StatelessWidget {
  const _CitySelectorPill({
    required this.selectedCity,
    required this.runnerCount,
    required this.onTap,
  });

  final String? selectedCity;
  final int runnerCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final label = selectedCity != null
        ? '$selectedCity ($runnerCount)'
        : 'All Indonesia ($runnerCount)';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NearPaceSpacing.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusPill),
          border: Border.all(
            color: selectedCity != null ? colors.accent : colors.border,
            width: selectedCity != null ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 16,
              color: selectedCity != null
                  ? colors.accent
                  : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: selectedCity != null
                    ? colors.accentText
                    : colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

void _showCitySearchSheet(
  BuildContext context, {
  required NearPaceController controller,
  required String userCity,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _SearchableCityFilterSheet(
        controller: controller,
        userCity: userCity,
      );
    },
  );
}

class _SearchableCityFilterSheet extends StatefulWidget {
  const _SearchableCityFilterSheet({
    required this.controller,
    required this.userCity,
  });

  final NearPaceController controller;
  final String userCity;

  @override
  State<_SearchableCityFilterSheet> createState() =>
      _SearchableCityFilterSheetState();
}

class _SearchableCityFilterSheetState
    extends State<_SearchableCityFilterSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final controller = widget.controller;
    final selectedCity = controller.selectedCity;
    final availableCities = controller.availableCities;
    final allEntries = controller.leaderboardEntries;

    final filteredCities = availableCities.where((c) {
      if (_query.isEmpty) return true;
      return c.toLowerCase().contains(_query);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
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
                    child: Text('Filter by City', style: textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search Field
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.md,
                vertical: NearPaceSpacing.xs,
              ),
              child: TextField(
                controller: _searchCtrl,
                style: textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search city...',
                  hintStyle: textTheme.bodyMedium?.copyWith(
                    color: colors.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colors.textMuted,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: NearPaceSpacing.sm,
                    vertical: NearPaceSpacing.xs,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      NearPaceSpacing.radiusSm,
                    ),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      NearPaceSpacing.radiusSm,
                    ),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      NearPaceSpacing.radiusSm,
                    ),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
              ),
            ),

            // Pinned Shortcuts
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.md,
                vertical: NearPaceSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _PinnedCityTile(
                      label: 'All Indonesia',
                      count: allEntries.length,
                      isSelected: selectedCity == null,
                      icon: Icons.flag_outlined,
                      onTap: () {
                        controller.setSelectedCity(null);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  if (widget.userCity.isNotEmpty) ...[
                    const SizedBox(width: NearPaceSpacing.sm),
                    Expanded(
                      child: _PinnedCityTile(
                        label: widget.userCity,
                        count: allEntries
                            .where(
                              (e) =>
                                  e.city.toLowerCase() ==
                                  widget.userCity.toLowerCase(),
                            )
                            .length,
                        isSelected:
                            selectedCity != null &&
                            selectedCity.toLowerCase() ==
                                widget.userCity.toLowerCase(),
                        icon: Icons.home_outlined,
                        onTap: () {
                          controller.setSelectedCity(widget.userCity);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(),

            // City list
            Expanded(
              child: filteredCities.isEmpty
                  ? Center(
                      child: Text(
                        'No active runners found in "${_searchCtrl.text}"',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NearPaceSpacing.md,
                        vertical: NearPaceSpacing.xs,
                      ),
                      itemCount: filteredCities.length,
                      separatorBuilder: (context, index) =>
                          Divider(color: colors.border, height: 1),
                      itemBuilder: (context, index) {
                        final city = filteredCities[index];
                        final isSelected =
                            selectedCity != null &&
                            selectedCity.toLowerCase() == city.toLowerCase();
                        final count = allEntries
                            .where(
                              (e) => e.city.toLowerCase() == city.toLowerCase(),
                            )
                            .length;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: NearPaceSpacing.xs,
                            vertical: 2,
                          ),
                          title: Text(
                            city,
                            style: textTheme.bodyLarge?.copyWith(
                              color: isSelected
                                  ? colors.accentText
                                  : colors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(
                                    NearPaceSpacing.radiusPill,
                                  ),
                                ),
                                child: Text(
                                  '$count ${count == 1 ? 'runner' : 'runners'}',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: colors.accent,
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                          onTap: () {
                            controller.setSelectedCity(city);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedCityTile extends StatelessWidget {
  const _PinnedCityTile({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.deepGreenSurface : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colors.accent : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? colors.accentText
                          : colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$count runners',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                  NearPaceAvatar(
                    avatarId: entry.avatarId,
                    name: entry.displayName,
                    size: isFirst ? 42 : 36,
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
            NearPaceAvatar(
              avatarId: entry.avatarId,
              name: entry.displayName,
              size: 36,
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
