import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../theme/app_theme.dart';
import 'meal_image.dart';
import 'skeleton.dart';
import 'view_recipe_badge.dart';

/// Kartu rekomendasi "Saran hari ini" dari `random.php`. Widget ini hanya
/// mengurus tampilan empat keadaannya (skeleton awal, konten, refresh
/// berjalan, error); pemanggil memegang data dan callback.
class RandomRecipeCard extends StatelessWidget {
  const RandomRecipeCard({
    super.key,
    required this.meal,
    required this.refreshing,
    required this.errorMessage,
    required this.heroTag,
    required this.onRetry,
    required this.onRefresh,
    required this.onTap,
  });

  final Meal? meal;

  /// True saat request random berjalan. Saat meal sudah ada, konten tetap
  /// tampil dan tombol refresh diganti indikator penuh agar tinggi kartu
  /// tidak bergeser.
  final bool refreshing;
  final String? errorMessage;
  final String heroTag;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meal = this.meal;
    if (meal == null) {
      if (refreshing) return const _RandomCardSkeleton();
      return _CardMessage(
        icon: Icons.error_outline,
        message: errorMessage ?? 'Rekomendasi tidak tersedia.',
        onRetry: onRetry,
      );
    }

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
                      aspectRatio: 16 / 9,
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
                    Row(
                      children: [
                        const _TodayChip(),
                        const Spacer(),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: refreshing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Sarankan resep lain',
                                    onPressed: onRefresh,
                                    icon: const Icon(Icons.refresh),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ResepinSpacing.sm),
                    Text(
                      meal.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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

/// Label kecil terakota — satu-satunya pemakaian warna aksen di Beranda.
class _TodayChip extends StatelessWidget {
  const _TodayChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ResepinSpacing.sm,
        vertical: ResepinSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResepinRadius.chip),
        border: Border.all(color: ResepinColors.accent),
      ),
      child: const Text(
        'Saran hari ini',
        style: TextStyle(
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: ResepinColors.accent,
        ),
      ),
    );
  }
}

class _RandomCardSkeleton extends StatelessWidget {
  const _RandomCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ResepinDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: SkeletonBox(radius: 0)),
          Padding(
            padding: EdgeInsets.all(ResepinSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 104, height: 24),
                SizedBox(height: ResepinSpacing.sm),
                SkeletonBox(height: 22),
                SizedBox(height: ResepinSpacing.sm),
                SkeletonBox(width: 200, height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Blok pesan (error/gagal) di dalam kartu dengan tinggi serupa kartu
/// aslinya. Pesan diumumkan sebagai live region untuk screen reader.
class _CardMessage extends StatelessWidget {
  const _CardMessage({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ResepinSpacing.lg),
        decoration: ResepinDecorations.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: ResepinColors.destructive),
            const SizedBox(height: ResepinSpacing.sm),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: ResepinSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
