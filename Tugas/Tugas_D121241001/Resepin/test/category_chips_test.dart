import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resepin/models/meal_category.dart';
import 'package:resepin/theme/app_theme.dart';
import 'package:resepin/widgets/category_chips.dart';

void main() {
  testWidgets('menampilkan chip, indikator gulir, dan memanggil onSelected', (
    tester,
  ) async {
    final categories = [
      for (var i = 0; i < 14; i++) MealCategory(id: '$i', name: 'Kategori $i'),
    ];
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildResepinTheme(),
        home: Scaffold(
          body: CategoryChips(
            categories: categories,
            selected: 'Kategori 0',
            onSelected: (name) => selected = name,
          ),
        ),
      ),
    );

    // Kategori di luar layar tetap ada di tree (digeser, bukan dibuang).
    expect(find.text('Kategori 0'), findsOneWidget);
    expect(find.text('Kategori 13'), findsOneWidget);
    // Indikator gulir dirender oleh widget Scrollbar.
    expect(find.byType(Scrollbar), findsOneWidget);

    await tester.tap(find.text('Kategori 1'));
    expect(selected, 'Kategori 1');
  });
}
