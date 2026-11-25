import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/run_group.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../../utils/formatters.dart';
import '../widgets/nearpace_avatar.dart';
import '../widgets/nearpace_card.dart';
import '../widgets/state_views.dart';

/// Detail and weekly leaderboard screen for a specific running circle.
class CircleDetailScreen extends StatefulWidget {
  const CircleDetailScreen({
    super.key,
    required this.groupId,
    this.initialGroup,
  });

  final String groupId;
  final RunGroup? initialGroup;

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  bool _isMutating = false;
  bool _hadGroupInController = false;

  Future<void> _copyInviteCode(RunGroup group) async {
    await Clipboard.setData(ClipboardData(text: group.inviteCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code ${group.inviteCode} copied to clipboard.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareInviteCode(RunGroup group) async {
    final goalPart = group.weeklyGoalKm != null
        ? ' Our weekly goal is ${group.weeklyGoalKm!.toStringAsFixed(0)} km!'
        : '';
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Join my NearPace running circle "${group.name}"!$goalPart '
            'Use invite code: ${group.inviteCode}',
        subject: 'Join ${group.name} on NearPace',
      ),
    );
  }

  Future<void> _confirmLeave(RunGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave circle?'),
        content: Text(
          'You will be removed from "${group.name}" and its weekly '
          'leaderboard. You can rejoin later with the invite code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isMutating = true);
    try {
      await context.read<NearPaceController>().leaveGroup(group.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Left "${group.name}".')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMutating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not leave circle: $e')));
    }
  }

  Future<void> _confirmDelete(RunGroup group) async {
    final colors = context.npColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete circle?'),
        content: Text(
          'This will permanently delete "${group.name}" and remove all '
          '${group.memberCount} member(s) from this circle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Circle'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isMutating = true);
    try {
      await context.read<NearPaceController>().deleteGroup(group.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Deleted "${group.name}".')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMutating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete circle: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final liveGroup = controller.groupById(widget.groupId);
    if (liveGroup != null) {
      _hadGroupInController = true;
    }
    final group =
        liveGroup ?? (_hadGroupInController ? null : widget.initialGroup);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Circle')),
        body: const Center(
          child: EmptyStateView(
            icon: Icons.groups_outlined,
            title: 'Circle unavailable',
            message: 'This circle was deleted or you are no longer a member.',
          ),
        ),
      );
    }

    final currentUid = controller.profile.uid;
    final isOwner = group.isOwner(currentUid);
    final members = controller.groupMembersFor(group.id);
    final totalCircleMeters = members.fold(0.0, (sum, m) => sum + m.distanceM);

    GroupMemberRank? currentMember;
    for (final m in members) {
      if (m.uid == currentUid) {
        currentMember = m;
        break;
      }
    }
    final userWeeklyKm =
        (currentMember?.distanceM ?? controller.weeklyDistanceMeters) / 1000.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = NearPaceSpacing.pageGutter(constraints.maxWidth);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: NearPaceSpacing.maxContentWidth,
              ),
              child: CustomScrollView(
                key: const ValueKey('circle-detail-scroll'),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      NearPaceSpacing.md,
                      gutter,
                      NearPaceSpacing.xxxl,
                    ),
                    sliver: SliverList.list(
                      children: [
                        // Circle header & invite code card
                        NearPaceCard(
                          elevated: true,
                          padding: const EdgeInsets.all(NearPaceSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: colors.deepGreenSurface,
                                      borderRadius: BorderRadius.circular(
                                        NearPaceSpacing.radiusMd,
                                      ),
                                      border: Border.all(
                                        color: colors.accent.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.groups_rounded,
                                      color: colors.accent,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: NearPaceSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.name,
                                          style: textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${group.memberCount} / ${group.maxMembers} members · '
                                          '${NearPaceFormatters.weekRangeLabel(controller.now)}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.accent,
                                        borderRadius: BorderRadius.circular(
                                          NearPaceSpacing.radiusPill,
                                        ),
                                      ),
                                      child: Text(
                                        'OWNER',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colors.onAccent,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (group.description != null &&
                                  group.description!.isNotEmpty) ...[
                                const SizedBox(height: NearPaceSpacing.sm),
                                Text(
                                  group.description!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: NearPaceSpacing.md),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: NearPaceSpacing.sm,
                                  vertical: NearPaceSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.background,
                                  borderRadius: BorderRadius.circular(
                                    NearPaceSpacing.radiusSm,
                                  ),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'INVITE CODE',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colors.textMuted,
                                                  fontSize: 10,
                                                  letterSpacing: 1.0,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            group.inviteCode,
                                            key: const ValueKey(
                                              'circle-invite-code',
                                            ),
                                            style: textTheme.titleMedium
                                                ?.copyWith(
                                                  color: colors.accentText,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 3.0,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      key: const ValueKey('copy-invite-code'),
                                      tooltip: 'Copy invite code',
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 20,
                                      ),
                                      color: colors.textPrimary,
                                      onPressed: () => _copyInviteCode(group),
                                    ),
                                    IconButton(
                                      key: const ValueKey('share-invite-code'),
                                      tooltip: 'Share invite code',
                                      icon: const Icon(
                                        Icons.share_rounded,
                                        size: 20,
                                      ),
                                      color: colors.accentText,
                                      onPressed: () => _shareInviteCode(group),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Weekly Goal progress bar (if configured)
                        if (group.weeklyGoalKm != null &&
                            group.weeklyGoalKm! > 0) ...[
                          const SizedBox(height: NearPaceSpacing.md),
                          _WeeklyGoalCard(
                            userWeeklyKm: userWeeklyKm,
                            goalKm: group.weeklyGoalKm!,
                            totalCircleMeters: totalCircleMeters,
                          ),
                        ],

                        const SizedBox(height: NearPaceSpacing.lg),

                        // Weekly ranking header
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Weekly Standings',
                                style: textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              'Total ${NearPaceFormatters.distanceKm(totalCircleMeters)}',
                              style: textTheme.labelMedium?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: NearPaceSpacing.sm),

                        if (members.isEmpty)
                          const EmptyStateView(
                            icon: Icons.directions_run_rounded,
                            title: 'No runs logged this week yet',
                            message:
                                'Complete a run to kick off this week\'s '
                                'circle standings.',
                          )
                        else
                          ...List.generate(members.length, (index) {
                            final member = members[index];
                            return Padding(
                              key: ValueKey('circle-member-${member.uid}'),
                              padding: EdgeInsets.only(
                                bottom: index == members.length - 1
                                    ? 0
                                    : NearPaceSpacing.xs,
                              ),
                              child: _CircleMemberRow(
                                rank: index + 1,
                                member: member,
                                isCurrentUser: member.uid == currentUid,
                                isOwner: group.isOwner(member.uid),
                              ),
                            );
                          }),

                        const SizedBox(height: NearPaceSpacing.xl),

                        // Leave or Delete Circle action
                        if (isOwner)
                          OutlinedButton.icon(
                            key: const ValueKey('delete-circle-button'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.danger,
                              side: BorderSide(
                                color: colors.danger.withValues(alpha: 0.5),
                              ),
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: _isMutating
                                ? null
                                : () => _confirmDelete(group),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Delete Circle'),
                          )
                        else
                          OutlinedButton.icon(
                            key: const ValueKey('leave-circle-button'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.danger,
                              side: BorderSide(
                                color: colors.danger.withValues(alpha: 0.5),
                              ),
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: _isMutating
                                ? null
                                : () => _confirmLeave(group),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Leave Circle'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({
    required this.userWeeklyKm,
    required this.goalKm,
    required this.totalCircleMeters,
  });

  final double userWeeklyKm;
  final double goalKm;
  final double totalCircleMeters;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final rawRatio = goalKm > 0 ? userWeeklyKm / goalKm : 0.0;
    final clampedRatio = rawRatio.clamp(0.0, 1.0);
    final pct = (rawRatio * 100).round();
    final achieved = rawRatio >= 1.0;

    return NearPaceCard(
      padding: const EdgeInsets.all(NearPaceSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                achieved ? Icons.verified_rounded : Icons.flag_outlined,
                size: 18,
                color: achieved ? colors.performanceGreen : colors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Weekly Goal Target', style: textTheme.titleSmall),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: achieved
                      ? colors.deepGreenSurface
                      : colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(
                    NearPaceSpacing.radiusPill,
                  ),
                  border: Border.all(
                    color: achieved ? colors.performanceGreen : colors.border,
                  ),
                ),
                child: Text(
                  '$pct%',
                  style: textTheme.labelSmall?.copyWith(
                    color: achieved
                        ? colors.performanceGreen
                        : colors.accentText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NearPaceSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(NearPaceSpacing.radiusPill),
            child: LinearProgressIndicator(
              key: const ValueKey('circle-weekly-goal-bar'),
              value: clampedRatio,
              minHeight: 10,
              backgroundColor: colors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                achieved ? colors.performanceGreen : colors.accent,
              ),
            ),
          ),
          const SizedBox(height: NearPaceSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your progress: ${userWeeklyKm.toStringAsFixed(2)} / '
                  '${goalKm.toStringAsFixed(1)} km',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              Text(
                'Circle: ${NearPaceFormatters.distanceKm(totalCircleMeters)}',
                style: textTheme.labelSmall?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleMemberRow extends StatelessWidget {
  const _CircleMemberRow({
    required this.rank,
    required this.member,
    required this.isCurrentUser,
    required this.isOwner,
  });

  final int rank;
  final GroupMemberRank member;
  final bool isCurrentUser;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final isTop3 = rank <= 3;

    Color rankBadgeColor;
    Color rankTextColor;
    if (rank == 1) {
      rankBadgeColor = colors.accent;
      rankTextColor = colors.onAccent;
    } else if (rank == 2) {
      rankBadgeColor = colors.performanceGreen.withValues(alpha: 0.22);
      rankTextColor = colors.performanceGreen;
    } else if (rank == 3) {
      rankBadgeColor = colors.warningSurface;
      rankTextColor = colors.warning;
    } else {
      rankBadgeColor = colors.surfaceElevated;
      rankTextColor = colors.textSecondary;
    }

    final paceLabel = member.avgPaceSecPerKm != null
        ? '${NearPaceFormatters.paceValue(member.avgPaceSecPerKm)} /km'
        : '--:-- /km';

    return NearPaceCard(
      elevated: isCurrentUser || rank == 1,
      borderColor: isCurrentUser
          ? colors.accent
          : (isTop3 ? colors.accent.withValues(alpha: 0.35) : null),
      padding: const EdgeInsets.symmetric(
        horizontal: NearPaceSpacing.md,
        vertical: NearPaceSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankBadgeColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: textTheme.labelMedium?.copyWith(
                color: rankTextColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: NearPaceSpacing.sm),
          NearPaceAvatar(
            avatarId: member.avatarId,
            name: member.displayName,
            size: 38,
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
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: isCurrentUser
                              ? colors.accentText
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
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
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    if (isOwner) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 15,
                        color: colors.warning,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${member.runCount} ${member.runCount == 1 ? 'run' : 'runs'} · $paceLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: NearPaceSpacing.xs),
          Text(
            NearPaceFormatters.distanceKm(member.distanceM),
            style: textTheme.titleSmall?.copyWith(
              color: isTop3 || isCurrentUser
                  ? colors.accentText
                  : colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
