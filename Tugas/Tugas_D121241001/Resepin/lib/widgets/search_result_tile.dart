import 'package:flutter/material.dart';

import '../models/meal.dart';
import '../theme/app_theme.dart';
import 'meal_image.dart';

/// Satu baris hasil pencarian: thumbnail persegi 72 dp, nama resep, dan
/// metadata yang tersedia (kategori · asal) — semuanya null-safe, tidak
/// ada data yang dikarang. Baris dibuat berbeda struktur dari kartu grid
/// Beranda agar dua layar mudah dibedakan, dan dapat diketuk untuk membuka
/// detail.
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.meal,
    required this.heroTag,
    required this.onTap,
  });

  final Meal meal;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _metaText(meal);
    return Container(
      decoration: ResepinDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ResepinSpacing.md),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(ResepinRadius.chip),
                  child: Hero(
                    tag: heroTag,
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: MealImage(url: meal.thumbnailUrl),
                    ),
                  ),
                ),
                const SizedBox(width: ResepinSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        meal.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: ResepinColors.ink,
                        ),
                      ),
                      if (meta != null) ...[
                        const SizedBox(height: ResepinSpacing.xs),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _metaText(Meal meal) {
    final parts = [
      meal.category,
      meal.originLabel,
    ].whereType<String>().where((text) => text.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
