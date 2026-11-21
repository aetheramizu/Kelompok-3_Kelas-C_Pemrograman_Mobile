import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../widgets/state_views.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'record_run_screen.dart';

/// Main authenticated NearPace navigation shell with four peer tabs (Home,
/// History, Leaderboard, Profile), a center Start Run action, and a top slot
/// for foreground FCM notifications.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _screens = <Widget>[
    HomeScreen(),
    HistoryScreen(),
    LeaderboardScreen(),
    ProfileScreen(),
  ];

  void _openRecorder(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const RecordRunScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();
    final colors = context.npColors;
    final tabIndex = controller.selectedTabIndex.clamp(0, _screens.length - 1);
    final notice = controller.activeNotice;

    return PopScope(
      canPop: tabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && tabIndex != 0) {
          controller.setTabIndex(0);
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              IndexedStack(index: tabIndex, children: _screens),
              if (notice != null)
                Positioned(
                  left: NearPaceSpacing.md,
                  right: NearPaceSpacing.md,
                  top: NearPaceSpacing.xs,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: NearPaceSpacing.maxContentWidth,
                      ),
                      child: ForegroundNoticeBanner(
                        notice: notice,
                        onDismiss: controller.dismissNotification,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _NearPaceBottomBar(
          selectedIndex: tabIndex,
          backgroundColor: colors.surface,
          borderColor: colors.border,
          onSelectTab: controller.setTabIndex,
          onStartRun: () => _openRecorder(context),
        ),
      ),
    );
  }
}

class _NearPaceBottomBar extends StatelessWidget {
  const _NearPaceBottomBar({
    required this.selectedIndex,
    required this.backgroundColor,
    required this.borderColor,
    required this.onSelectTab,
    required this.onStartRun,
  });

  final int selectedIndex;
  final Color backgroundColor;
  final Color borderColor;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onStartRun;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NearPaceSpacing.xs,
            vertical: NearPaceSpacing.xs,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: NearPaceSpacing.maxContentWidth,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NavTabButton(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      selected: selectedIndex == 0,
                      onTap: () => onSelectTab(0),
                    ),
                  ),
                  Expanded(
                    child: _NavTabButton(
                      icon: Icons.history_outlined,
                      activeIcon: Icons.history_rounded,
                      label: 'History',
                      selected: selectedIndex == 1,
                      onTap: () => onSelectTab(1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Semantics(
                      button: true,
                      label: 'Record run',
                      child: Material(
                        color: colors.accent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onStartRun,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Icon(
                              Icons.directions_run_rounded,
                              size: 26,
                              color: colors.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _NavTabButton(
                      icon: Icons.leaderboard_outlined,
                      activeIcon: Icons.leaderboard_rounded,
                      label: 'Ranks',
                      selected: selectedIndex == 2,
                      onTap: () => onSelectTab(2),
                    ),
                  ),
                  Expanded(
                    child: _NavTabButton(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile',
                      selected: selectedIndex == 3,
                      onTap: () => onSelectTab(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final fg = selected ? colors.accentText : colors.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: NearPaceSpacing.minTapTarget,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, size: 22, color: fg),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
