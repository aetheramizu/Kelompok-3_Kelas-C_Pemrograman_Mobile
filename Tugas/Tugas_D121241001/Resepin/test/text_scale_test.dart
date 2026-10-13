import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resepin/models/meal.dart';
import 'package:resepin/ui/screens/recipe_detail_screen.dart';
import 'package:resepin/theme/app_theme.dart';
import 'package:resepin/ui/widgets/recipe_grid.dart';

/// Audit Fase 5: layout tidak boleh overflow pada skala teks besar
/// (aksesibilitas). Error overflow direkam test framework sebagai
/// exception, jadi assertion-nya `takeException() == null`.
void main() {
  Widget wrap(double scale, Widget child) {
    return MaterialApp(
      theme: buildResepinTheme(),
      builder: (context, appChild) => MediaQuery.withClampedTextScaling(
        minScaleFactor: scale,
        maxScaleFactor: scale,
        child: appChild!,
      ),
      home: Scaffold(body: child),
    );
  }

  void usePhoneViewport(WidgetTester tester, {double height = 2400}) {
    // 1080x{height} fisik @ dpr 3 → 360 dp lebar (ponsel kecil).
    tester.view.physicalSize = Size(1080, height);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  for (final scale in [1.3, 2.0]) {
    testWidgets('RecipeGrid tanpa overflow pada skala teks ${scale}x', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final meals = [
        Meal.fromJson(const {
          'idMeal': '1',
          'strMeal': 'Nama Resep Yang Sangat Panjang Sekali Dua Baris Penuh',
          'strArea': 'Italian',
        })!,
        Meal.fromJson(const {'idMeal': '2', 'strMeal': 'Resep Dua'})!,
      ];

      await tester.pumpWidget(
        wrap(
          scale,
          ListView(
            children: [RecipeGrid(meals: meals, onMealTap: (_) {})],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Nama Resep'), findsOneWidget);
    });
  }

  testWidgets('Detail lengkap tanpa overflow pada skala teks 2.0x', (
    tester,
  ) async {
    usePhoneViewport(tester, height: 6000);
    final meal = Meal.fromJson(const {
      'idMeal': '52771',
      'strMeal': 'Spicy Arrabiata Penne Dengan Nama Sangat Panjang',
      'strCategory': 'Vegetarian',
      'strArea': 'Italian',
      'strInstructions':
          'Langkah pertama yang cukup panjang untuk menguji pembungkusan '
          'teks pada layar kecil dengan skala besar.\r\n'
          'Langkah kedua.',
      'strIngredient1': 'Penne rigate yang panjang',
      'strMeasure1': '1 pound dan sedikit lagi',
      'strIngredient2': 'Garlic',
      'strMeasure2': '',
    })!;

    await tester.pumpWidget(
      wrap(
        2.0,
        RecipeDetailScreen(
          mealId: '52771',
          initialMeal: meal,
          heroTag: 'scale-test',
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Bahan ('), findsOneWidget);
    expect(find.text('Cara membuat'), findsOneWidget);
  });
}
