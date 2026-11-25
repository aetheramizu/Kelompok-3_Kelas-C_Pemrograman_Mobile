import 'package:material_ui/material_ui.dart';

import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import 'nearpace_avatar.dart';
import 'nearpace_card.dart';

/// Interactive bottom sheet for browsing and picking one of the 12 character avatars.
class AvatarPickerSheet extends StatefulWidget {
  const AvatarPickerSheet({super.key, this.currentAvatarId});

  final String? currentAvatarId;

  static Future<String?> show(BuildContext context, {String? currentAvatarId}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarPickerSheet(currentAvatarId: currentAvatarId),
    );
  }

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  String? _selectedId;
  String _activeCategory = 'all'; // 'all', 'runners', 'mascots'

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentAvatarId ?? kNearPaceAvatars.first.id;
  }

  List<AvatarCharacter> get _filteredList {
    if (_activeCategory == 'runners') {
      return kNearPaceAvatars.where((a) => a.category == 'runners').toList();
    }
    if (_activeCategory == 'mascots') {
      return kNearPaceAvatars.where((a) => a.category == 'mascots').toList();
    }
    return kNearPaceAvatars;
  }

  AvatarCharacter get _currentSelected {
    return kNearPaceAvatars.firstWhere(
      (a) => a.id == _selectedId,
      orElse: () => kNearPaceAvatars.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final selected = _currentSelected;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                    child: Text(
                      'Choose Your Character',
                      style: textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Selected preview card
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.md,
              ),
              child: NearPaceCard(
                padding: const EdgeInsets.all(NearPaceSpacing.sm),
                child: Row(
                  children: [
                    NearPaceAvatar(avatarId: selected.id, size: 56),
                    const SizedBox(width: NearPaceSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                selected.name,
                                style: textTheme.titleSmall?.copyWith(
                                  color: colors.accentText,
                                ),
                              ),
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
                                  selected.category == 'mascots'
                                      ? 'Mascot'
                                      : 'Runner',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selected.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: NearPaceSpacing.xs),

            // Category Chips
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.md,
              ),
              child: Row(
                children: [
                  _CategoryChip(
                    label: 'All (12)',
                    selected: _activeCategory == 'all',
                    onTap: () => setState(() => _activeCategory = 'all'),
                  ),
                  const SizedBox(width: NearPaceSpacing.xs),
                  _CategoryChip(
                    label: 'Runners (8)',
                    selected: _activeCategory == 'runners',
                    onTap: () => setState(() => _activeCategory = 'runners'),
                  ),
                  const SizedBox(width: NearPaceSpacing.xs),
                  _CategoryChip(
                    label: 'Mascots (4)',
                    selected: _activeCategory == 'mascots',
                    onTap: () => setState(() => _activeCategory = 'mascots'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: NearPaceSpacing.xs),

            // Avatar Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: NearPaceSpacing.md,
                  vertical: NearPaceSpacing.xs,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  crossAxisSpacing: NearPaceSpacing.sm,
                  mainAxisSpacing: NearPaceSpacing.sm,
                  childAspectRatio: 0.88,
                ),
                itemCount: _filteredList.length,
                itemBuilder: (context, index) {
                  final character = _filteredList[index];
                  final isSelected = _selectedId == character.id;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedId = character.id;
                      });
                    },
                    borderRadius: BorderRadius.circular(
                      NearPaceSpacing.radiusSm,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.deepGreenSurface
                            : colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(
                          NearPaceSpacing.radiusSm,
                        ),
                        border: Border.all(
                          color: isSelected ? colors.accent : colors.border,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(NearPaceSpacing.xs),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          NearPaceAvatar(avatarId: character.id, size: 48),
                          const SizedBox(height: NearPaceSpacing.xs),
                          Text(
                            character.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? colors.accentText
                                  : colors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Save Button
            Padding(
              padding: EdgeInsets.fromLTRB(
                NearPaceSpacing.md,
                NearPaceSpacing.xs,
                NearPaceSpacing.md,
                MediaQuery.of(context).padding.bottom + NearPaceSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
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
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    'Select ${selected.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => Navigator.of(context).pop(_selectedId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
        fontSize: 12,
      ),
      selectedColor: colors.accent,
      backgroundColor: colors.surfaceElevated,
      side: BorderSide(color: selected ? colors.accent : colors.border),
      onSelected: (_) => onTap(),
    );
  }
}
