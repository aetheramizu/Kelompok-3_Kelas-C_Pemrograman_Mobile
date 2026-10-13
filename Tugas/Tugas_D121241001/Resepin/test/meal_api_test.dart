import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:resepin/services/meal_api.dart';

void main() {
  // Semua test memakai MockClient — tidak ada jaringan sungguhan.
  group('MealApi — pembentukan endpoint', () {
    test('searchMeals menyusun URL dan query yang benar', () async {
      Uri? captured;
      final api = MealApi(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response('{"meals":[]}', 200);
        }),
      );

      final result = await api.searchMeals('chicken soup');

      expect(result, isEmpty);
      expect(captured!.scheme, 'https');
      expect(captured!.host, 'www.themealdb.com');
      expect(captured!.path, '/api/json/v1/1/search.php');
      // Query di-decode kembali dengan benar tanpa peduli gaya encoding.
      expect(captured!.queryParameters['s'], 'chicken soup');
    });

    test('randomMeal tanpa query string', () async {
      Uri? captured;
      final api = MealApi(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response('{"meals":null}', 200);
        }),
      );

      await api.randomMeal();

      expect(captured!.path, '/api/json/v1/1/random.php');
      expect(captured!.query, isEmpty);
    });
  });

  group('MealApi — konvensi respons TheMealDB', () {
    test('meals null berarti tidak ada hasil, bukan error', () async {
      final api = MealApi(
        client: MockClient((_) async => http.Response('{"meals":null}', 200)),
      );

      expect(await api.searchMeals('tidakada'), isEmpty);
    });

    test('randomMeal meals null mengembalikan null', () async {
      final api = MealApi(
        client: MockClient((_) async => http.Response('{"meals":null}', 200)),
      );

      expect(await api.randomMeal(), isNull);
    });

    test(
      'lookupMeal mengembalikan meal pertama dari respons lengkap',
      () async {
        final api = MealApi(
          client: MockClient(
            (_) async => http.Response(
              '{"meals":[{"idMeal":"52772","strMeal":"Teriyaki Chicken '
              'Casserole","strCategory":"Chicken","strArea":"Japanese"}]}',
              200,
            ),
          ),
        );

        final meal = await api.lookupMeal('52772');
        expect(meal, isNotNull);
        expect(meal!.id, '52772');
        expect(meal.name, 'Teriyaki Chicken Casserole');
      },
    );

    test('entri tanpa id/nama disaring dari hasil list', () async {
      final api = MealApi(
        client: MockClient(
          (_) async => http.Response(
            '{"meals":[{"idMeal":"1","strMeal":"Valid"},'
            '{"strMeal":"Tanpa id"}]}',
            200,
          ),
        ),
      );

      final result = await api.searchMeals('x');
      expect(result, hasLength(1));
      expect(result.first.name, 'Valid');
    });
  });

  group('MealApi — pemetaan error', () {
    test('HTTP non-200 menjadi MealApiError.server', () async {
      final api = MealApi(
        client: MockClient((_) async => http.Response('error', 500)),
      );

      await expectLater(
        api.searchMeals('x'),
        throwsA(
          isA<MealApiException>().having(
            (e) => e.error,
            'error',
            MealApiError.server,
          ),
        ),
      );
    });

    test('respons bukan JSON menjadi MealApiError.invalidResponse', () async {
      final api = MealApi(
        client: MockClient((_) async => http.Response('<html>', 200)),
      );

      await expectLater(
        api.searchMeals('x'),
        throwsA(
          isA<MealApiException>().having(
            (e) => e.error,
            'error',
            MealApiError.invalidResponse,
          ),
        ),
      );
    });

    test('kegagalan jaringan menjadi MealApiError.network', () async {
      final api = MealApi(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );

      await expectLater(
        api.searchMeals('x'),
        throwsA(
          isA<MealApiException>().having(
            (e) => e.error,
            'error',
            MealApiError.network,
          ),
        ),
      );
    });
  });

  group('MealApi — kategori', () {
    test('fetchCategories memetakan respons categories.php', () async {
      final api = MealApi(
        client: MockClient(
          (_) async => http.Response(
            '{"categories":[{"idCategory":"1","strCategory":"Beef",'
            '"strCategoryThumb":"https://www.themealdb.com/images/category/'
            'beef.png","strCategoryDescription":"daging"}]}',
            200,
          ),
        ),
      );

      final categories = await api.fetchCategories();
      expect(categories, hasLength(1));
      expect(categories.first.name, 'Beef');
    });
  });
}
