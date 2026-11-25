import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/run_group.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../screens/circle_detail_screen.dart';
import 'circles_sheets.dart';
import 'nearpace_card.dart';
import 'state_views.dart';

/// NearPace segmented control switching between City (`Kota`) and `Circles`
/// views inside [LeaderboardScreen].
class LeaderboardModeSwitch extends StatelessWidget {
  const LeaderboardModeSwitch({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    this.circleCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final int circleCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(NearPaceSpacing.radiusPill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              key: const ValueKey('leaderboard-tab-kota'),
              label: 'Kota',
              icon: Icons.location_city_rounded,
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
              colors: colors,
              textTheme: textTheme,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentButton(
              key: const ValueKey('leaderboard-tab-circles'),
              label: circleCount > 0 ? 'Circles ($circleCount)' : 'Circles',
              icon: Icons.groups_rounded,
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
              colors: colors,
              textTheme: textTheme,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.colors,
    required this.textTheme,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final NearPaceColors colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(NearPaceSpacing.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NearPaceSpacing.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? colors.onAccent : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: selected ? colors.onAccent : colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the Circles list or friendly empty state inside [LeaderboardScreen].
class CirclesTabContent extends StatelessWidget {
  const CirclesTabContent({super.key});

  Future<void> _openCreateCircle(BuildContext context) async {
    final created = await CreateCircleSheet.show(context);
    if (created == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Created "${created.name}" · Code: ${created.inviteCode}',
        ),
      ),
    );
  }

  Future<void> _openJoinCircle(BuildContext context) async {
    final joined = await JoinCircleSheet.show(context);
    if (joined == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Joined "${joined.name}"!')));
  }

  void _openDetail(BuildContext context, RunGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CircleDetailScreen(groupId: group.id, initialGroup: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final groups = controller.userGroups;

    if (controller.groupsState == ViewLoadState.loading) {
      return const LoadingSkeletonList(itemCount: 3);
    }

    if (controller.groupsState == ViewLoadState.error) {
      return ErrorStateView(
        title: 'Could not load your circles',
        message:
            controller.groupsError ??
            'Unable to fetch your running circles right now.',
        onRetry: controller.refreshGroups,
      );
    }

    if (groups.isEmpty) {
      return NearPaceCard(
        elevated: true,
        padding: const EdgeInsets.all(NearPaceSpacing.lg),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.deepGreenSurface,
                borderRadius: BorderRadius.circular(NearPaceSpacing.radiusLg),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(Icons.groups_rounded, size: 30, color: colors.accent),
            ),
            const SizedBox(height: NearPaceSpacing.md),
            Text(
              'Run stronger with a Circle',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: NearPaceSpacing.xs),
            Text(
              'Create a private weekly distance challenge with friends or '
              'join an existing crew using their 6-character invite code.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: NearPaceSpacing.lg),
            Wrap(
              spacing: NearPaceSpacing.sm,
              runSpacing: NearPaceSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  key: const ValueKey('empty-create-circle'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  onPressed: () => _openCreateCircle(context),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text(
                    'Create Circle',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('empty-join-circle'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    side: BorderSide(color: colors.border),
                  ),
                  onPressed: () => _openJoinCircle(context),
                  icon: const Icon(Icons.vpn_key_outlined, size: 18),
                  label: const Text('Join with Code'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quick action buttons
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('list-create-circle'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: () => _openCreateCircle(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Create Circle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: NearPaceSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('list-join-circle'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  side: BorderSide(color: colors.border),
                ),
                onPressed: () => _openJoinCircle(context),
                icon: const Icon(Icons.vpn_key_outlined, size: 18),
                label: const Text(
                  'Join with Code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: NearPaceSpacing.md),

        Text(
          'My Circles',
          style: textTheme.titleSmall?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: NearPaceSpacing.xs),

        ...List.generate(groups.length, (index) {
          final group = groups[index];
          final userRank = controller.userRankInGroup(group.id);
          final members = controller.groupMembersFor(group.id);
          GroupMemberRank? myMember;
          for (final m in members) {
            if (m.uid == controller.profile.uid) {
              myMember = m;
              break;
            }
          }
          final userKm =
              (myMember?.distanceM ?? controller.weeklyDistanceMeters) / 1000.0;

          return Padding(
            key: ValueKey('circle-card-${group.id}'),
            padding: EdgeInsets.only(
              bottom: index == groups.length - 1 ? 0 : NearPaceSpacing.sm,
            ),
            child: _CircleSummaryCard(
              group: group,
              isOwner: group.isOwner(controller.profile.uid),
              userRank: userRank,
              userWeeklyKm: userKm,
              onTap: () => _openDetail(context, group),
            ),
          );
        }),
      ],
    );
  }
}

class _CircleSummaryCard extends StatelessWidget {
  const _CircleSummaryCard({
    required this.group,
    required this.isOwner,
    required this.userRank,
    required this.userWeeklyKm,
    required this.onTap,
  });

  final RunGroup group;
  final bool isOwner;
  final int? userRank;
  final double userWeeklyKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final goalKm = group.weeklyGoalKm;
    final hasGoal = goalKm != null && goalKm > 0;
    final progress = hasGoal ? (userWeeklyKm / goalKm).clamp(0.0, 1.0) : 0.0;
    final pct = hasGoal ? ((userWeeklyKm / goalKm) * 100).round() : 0;

    return NearPaceCard(
      elevated: true,
      onTap: onTap,
      padding: const EdgeInsets.all(NearPaceSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.deepGreenSurface,
                  borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: 22,
                  color: colors.accent,
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
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.workspace_premium_rounded,
                            size: 16,
                            color: colors.warning,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'} · '
                      'Code ${group.inviteCode}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NearPaceSpacing.xs),
              if (userRank != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: userRank == 1
                        ? colors.accent
                        : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(
                      NearPaceSpacing.radiusPill,
                    ),
                    border: Border.all(
                      color: userRank == 1 ? colors.accent : colors.border,
                    ),
                  ),
                  child: Text(
                    '#$userRank',
                    style: textTheme.labelMedium?.copyWith(
                      color: userRank == 1
                          ? colors.onAccent
                          : colors.accentText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
          if (hasGoal) ...[
            const SizedBox(height: NearPaceSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      NearPaceSpacing.radiusPill,
                    ),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 100 ? colors.performanceGreen : colors.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: NearPaceSpacing.sm),
                Text(
                  '${userWeeklyKm.toStringAsFixed(1)} / '
                  '${goalKm.toStringAsFixed(0)} km ($pct%)',
                  style: textTheme.labelSmall?.copyWith(
                    color: pct >= 100
                        ? colors.performanceGreen
                        : colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: NearPaceSpacing.xs),
            Text(
              'Your week: ${userWeeklyKm.toStringAsFixed(2)} km',
              style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
