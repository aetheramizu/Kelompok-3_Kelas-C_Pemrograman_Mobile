import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../theme/app_theme.dart';
import 'recipe_grid_card.dart';

/// Grid dua kolom: kartu dipasang berpasangan dalam satu Row.
///
/// [IntrinsicHeight] wajib ada di sini: ia memberi tinggi terbatas pada
/// Row sehingga `CrossAxisAlignment.stretch` menyamakan tinggi dua kartu
/// dalam satu baris (judul 1 baris vs 2 baris tetap rata). Tanpa itu,
/// `stretch` di dalam ListView yang tingginya tak terbatas membuat kartu
/// menerima constraint tinggi tak terbatas dan baris gagal dirender.
class RecipeGrid extends StatelessWidget {
  const RecipeGrid({super.key, required this.meals, required this.onMealTap});

  final List<Meal> meals;
  final ValueChanged<Meal> onMealTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < meals.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < meals.length ? ResepinSpacing.md : 0,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _card(meals[i])),
                  const SizedBox(width: ResepinSpacing.md),
                  if (i + 1 < meals.length)
                    Expanded(child: _card(meals[i + 1]))
                  else
                    // Jumlah ganjil: kolom kanan kosong dengan tinggi sama.
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(Meal meal) {
    return RecipeGridCard(
      key: ValueKey(meal.id),
      meal: meal,
      heroTag: 'home-grid-${meal.id}',
      onTap: () => onMealTap(meal),
    );
  }
}
