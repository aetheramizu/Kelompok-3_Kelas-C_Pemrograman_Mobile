import 'package:flutter_test/flutter_test.dart';

import 'package:resepin/models/meal.dart';
import 'package:resepin/models/meal_category.dart';

void main() {
  group('Meal.fromJson — bentuk lengkap (search/lookup/random)', () {
    test('memetakan field utama dan memangkas whitespace', () {
      final meal = Meal.fromJson(const {
        'idMeal': '52771',
        'strMeal': ' Spicy Arrabiata Penne ',
        'strMealThumb':
            'https://www.themealdb.com/images/media/meals/ustxww1511306288.jpg',
        'strCategory': 'Vegetarian',
        'strArea': 'Italian',
        'strCountry': 'Italy',
        'strInstructions': 'Langkah pertama.\r\n\r\n Langkah kedua.\r\n',
      });

      expect(meal, isNotNull);
      expect(meal!.id, '52771');
      expect(meal.name, 'Spicy Arrabiata Penne');
      expect(meal.category, 'Vegetarian');
      expect(meal.originLabel, 'Italian');
      expect(meal.hasFullDetail, isTrue);
      // Baris kosong dibuang, teks di-trim, tanpa penomoran artifisial.
      expect(meal.instructionParagraphs, [
        'Langkah pertama.',
        'Langkah kedua.',
      ]);
    });

    test('bahan kosong dan takaran kosong ditangani', () {
      final meal = Meal.fromJson(const {
        'idMeal': '1',
        'strMeal': 'Test',
        'strIngredient1': 'Penne Rigate',
        'strMeasure1': '1 pound',
        'strIngredient2': '  ',
        'strMeasure2': '2 cups',
        'strIngredient3': 'Garlic',
        'strMeasure3': '',
      });

      expect(meal!.ingredients, hasLength(2));
      expect(meal.ingredients[0].name, 'Penne Rigate');
      expect(meal.ingredients[0].measure, '1 pound');
      // Takaran kosong menjadi null, bukan string kosong.
      expect(meal.ingredients[1].name, 'Garlic');
      expect(meal.ingredients[1].measure, isNull);
    });

    test('instruksi null membuat hasFullDetail false dan paragraf kosong', () {
      final meal = Meal.fromJson(const {'idMeal': '1', 'strMeal': 'X'});
      expect(meal!.hasFullDetail, isFalse);
      expect(meal.instructionParagraphs, isEmpty);
      expect(meal.ingredients, isEmpty);
    });
  });

  group('Meal.fromJson — bentuk ringkas (filter.php)', () {
    test('field yang tidak dikirim API tetap null', () {
      final meal = Meal.fromJson(const {
        'strMeal': 'Beef and Mustard Pie',
        'strMealThumb':
            'https://www.themealdb.com/images/media/meals/sytuqu1511553755.jpg',
        'idMeal': '52874',
      });

      expect(meal, isNotNull);
      expect(meal!.id, '52874');
      expect(meal.category, isNull);
      expect(meal.area, isNull);
      expect(meal.thumbnailUrl, isNotNull);
    });
  });

  group('Meal.fromJson — label asal', () {
    test('area null turun ke country', () {
      final meal = Meal.fromJson(const {
        'idMeal': '1',
        'strMeal': 'Firni',
        'strArea': null,
        'strCountry': 'Afghanistan',
      });
      expect(meal!.originLabel, 'Afghanistan');
    });

    test('keduanya null tetap aman', () {
      final meal = Meal.fromJson(const {'idMeal': '2', 'strMeal': 'X'});
      expect(meal!.originLabel, isNull);
    });
  });

  group('Meal.fromJson — entri tidak valid', () {
    test('entri tanpa id atau nama ditolak', () {
      expect(Meal.fromJson(const {'strMeal': 'tanpa id'}), isNull);
      expect(Meal.fromJson(const {'idMeal': '1'}), isNull);
    });
  });

  group('MealCategory.fromJson', () {
    test('memetakan field kategori', () {
      final category = MealCategory.fromJson(const {
        'idCategory': '1',
        'strCategory': 'Beef',
        'strCategoryThumb':
            'https://www.themealdb.com/images/category/beef.png',
        'strCategoryDescription': 'Beef is the culinary name...',
      });

      expect(category, isNotNull);
      expect(category!.id, '1');
      expect(category.name, 'Beef');
      expect(category.imageUrl, isNotNull);
      expect(category.description, isNotNull);
    });

    test('entri tanpa nama ditolak', () {
      expect(MealCategory.fromJson(const {'idCategory': '1'}), isNull);
    });
  });
}
