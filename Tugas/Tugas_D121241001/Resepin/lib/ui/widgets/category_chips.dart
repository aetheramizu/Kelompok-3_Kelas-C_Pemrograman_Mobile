import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/meal_category.dart';
import '../../theme/app_theme.dart';

/// Baris chip kategori yang digeser horizontal. Chip aktif terisi hijau
/// utama dengan teks putih; lainnya outline. Semua target sentuh minimal
/// 48 dp dan state terpilih terekspor ke semantics.
///
/// Saat kategori meluap, indikator gulir tipis selalu tampil di bawah
/// baris (bukan hanya saat digeser) agar jelas baris ini masih bisa
/// digulir. Di web, baris juga dapat diseret dengan mouse karena roda
/// mouse vertikal tidak menggulir daftar horizontal.
///
/// Padding horizontal diatur pemanggil (lewat gutter layar), sehingga
/// baris chip sejajar dengan konten lain.
class CategoryChips extends StatefulWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<MealCategory> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<CategoryChips> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      // Izinkan seret mouse (web/desktop) menggeser baris horizontal.
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          // Track tipis selalu tampak saat meluap; thumb abu-abu di atasnya.
          thumbVisibility: const WidgetStatePropertyAll(true),
          trackVisibility: const WidgetStatePropertyAll(true),
          thickness: const WidgetStatePropertyAll(4),
          radius: const Radius.circular(2),
          thumbColor: WidgetStatePropertyAll(
            ResepinColors.inkMuted.withValues(alpha: 0.45),
          ),
          trackColor: const WidgetStatePropertyAll(ResepinColors.border),
        ),
        child: Scrollbar(
          controller: _controller,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            // Ruang di bawah chip agar indikator tidak menimpa chip.
            padding: const EdgeInsets.only(bottom: ResepinSpacing.sm),
            child: Row(
              children: [
                for (var i = 0; i < widget.categories.length; i++) ...[
                  if (i > 0) const SizedBox(width: ResepinSpacing.sm),
                  _CategoryChip(
                    label: widget.categories[i].name,
                    selected: widget.categories[i].name == widget.selected,
                    onTap: () => widget.onSelected(widget.categories[i].name),
                  ),
                ],
              ],
            ),
          ),
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
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ResepinRadius.chip),
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: ResepinSpacing.lg,
            vertical: ResepinSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? ResepinColors.primary : ResepinColors.surface,
            borderRadius: BorderRadius.circular(ResepinRadius.chip),
            border: Border.all(
              color: selected
                  ? ResepinColors.primary
                  : ResepinColors.borderStrong,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : ResepinColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
