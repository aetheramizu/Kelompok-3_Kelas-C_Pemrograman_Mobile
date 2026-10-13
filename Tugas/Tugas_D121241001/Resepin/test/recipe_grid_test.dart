import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resepin/models/meal.dart';
import 'package:resepin/theme/app_theme.dart';
import 'package:resepin/ui/widgets/recipe_grid.dart';

Meal _meal(String id, String name) =>
    Meal.fromJson({'idMeal': id, 'strMeal': name})!;

void main() {
  // Dokumentasi mekanisme bug: `Row(crossAxisAlignment: stretch)` di dalam
  // ListView (tinggi tak terbatas) memberi anaknya constraint tinggi tak
  // terbatas → layout gagal dan area grid dirender kosong tanpa error
  // widget (error fase layout tidak memunculkan ErrorWidget).
  testWidgets('tanpa IntrinsicHeight, Row stretch di ListView gagal layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: Container(color: Colors.red)),
                  Expanded(child: Container(color: Colors.blue)),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNotNull);
  });

  testWidgets('RecipeGrid dengan IntrinsicHeight merender kartu di ListView', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildResepinTheme(),
        home: Scaffold(
          body: ListView(
            children: [
              RecipeGrid(
                meals: [
                  _meal('1', 'Resep Satu'),
                  _meal('2', 'Resep Dua'),
                  _meal('3', 'Resep Tiga'),
                ],
                onMealTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Resep Satu'), findsOneWidget);
    expect(find.text('Resep Dua'), findsOneWidget);
    expect(find.text('Resep Tiga'), findsOneWidget);
  });
}
