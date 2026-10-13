import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resepin/models/meal.dart';
import 'package:resepin/ui/screens/recipe_detail_screen.dart';
import 'package:resepin/theme/app_theme.dart';
import 'package:resepin/ui/widgets/skeleton.dart';

void main() {
  // Konten detail lebih panjang dari viewport test default (800x600);
  // viewport tinggi menjaga seluruh section ter-build saat assertion.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('Detail memakai data lengkap tanpa request: judul, bahan, '
      'instruksi, tanpa bottom navigation', (tester) async {
    useTallViewport(tester);

    final meal = Meal.fromJson(const {
      'idMeal': '52771',
      'strMeal': 'Spicy Arrabiata Penne',
      'strCategory': 'Vegetarian',
      'strArea': 'Italian',
      'strInstructions': 'Rebus air.\r\n\r\nMasak pasta.',
      'strIngredient1': 'Penne rigate',
      'strMeasure1': '1 pound',
      'strIngredient2': 'Garlic',
      'strMeasure2': '',
    })!;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildResepinTheme(),
        home: RecipeDetailScreen(
          mealId: '52771',
          initialMeal: meal,
          heroTag: 'test-hero',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Spicy Arrabiata Penne'), findsOneWidget);
    expect(find.text('Vegetarian · Italian'), findsOneWidget);
    expect(find.text('Bahan (2)'), findsOneWidget);
    expect(find.text('Penne rigate'), findsOneWidget);
    expect(find.text('1 pound'), findsOneWidget);
    expect(find.text('Garlic'), findsOneWidget);
    expect(find.text('Cara membuat'), findsOneWidget);
    expect(find.text('Rebus air.'), findsOneWidget);
    expect(find.text('Masak pasta.'), findsOneWidget);
    // Detail tidak memakai bottom navigation.
    expect(find.text('Beranda'), findsNothing);
    expect(find.text('Cari'), findsNothing);
  });

  testWidgets('Data ringkas memicu lookup: skeleton dulu, lalu state error '
      'dengan retry (tanpa jaringan di lingkungan test)', (tester) async {
    final summary = Meal.fromJson(const {
      'idMeal': '52874',
      'strMeal': 'Beef and Mustard Pie',
    })!;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildResepinTheme(),
        home: RecipeDetailScreen(
          mealId: '52874',
          initialMeal: summary,
          heroTag: 'test-hero-2',
        ),
      ),
    );

    // Request berjalan: skeleton tampil.
    expect(find.byType(SkeletonBox), findsWidgets);

    await tester.pump();
    await tester.pump();

    // Request gagal: state error dengan tombol retry.
    expect(find.text('Coba lagi'), findsOneWidget);
  });
}
