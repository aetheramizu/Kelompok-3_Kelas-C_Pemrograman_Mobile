import 'package:flutter/material.dart';

import '../models/meal.dart';
import '../theme/app_theme.dart';
import 'meal_image.dart';
import 'view_recipe_badge.dart';

/// Kartu resep ringkas untuk grid dua kolom Beranda: gambar 4:3, nama
/// maksimal dua baris, dan asal masakan bila tersedia. Kartu dipasang
/// berpasangan oleh [RecipeGrid], yang menyamakan tinggi dua kartu dalam
/// satu baris.
///
/// Seluruh kartu dapat diketuk untuk membuka detail; [heroTag] diberi
/// prefiks sumber oleh pemanggil agar transisi Hero tidak bertabrakan
/// antar layar. Lencana "Lihat resep" di sudut gambar menandakan kartu
/// dapat diketuk tanpa menutupi foto.
class RecipeGridCard extends StatelessWidget {
  const RecipeGridCard({
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
    final origin = meal.originLabel;
    return Container(
      decoration: ResepinDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: heroTag,
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: MealImage(url: meal.thumbnailUrl),
                    ),
                  ),
                  const Positioned(
                    right: ResepinSpacing.sm,
                    bottom: ResepinSpacing.sm,
                    child: ViewRecipeBadge(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(ResepinSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (origin != null) ...[
                      const SizedBox(height: ResepinSpacing.xs),
                      Text(
                        origin,
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
    );
  }
}
