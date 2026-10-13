import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/meal.dart';
import '../models/meal_category.dart';

/// Jenis kegagalan yang mungkin terjadi saat memanggil TheMealDB.
enum MealApiError { network, server, invalidResponse }

/// Exception dari [MealApi]. [error] membedakan penyebabnya agar layar
/// dapat menampilkan pesan dan tombol retry yang tepat.
class MealApiException implements Exception {
  const MealApiException(this.error);

  final MealApiError error;

  String get message => switch (error) {
    MealApiError.network =>
      'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
    MealApiError.server => 'Server sedang bermasalah. Coba beberapa saat lagi.',
    MealApiError.invalidResponse => 'Respons server tidak valid.',
  };

  @override
  String toString() => message;
}

/// Klien terpusat untuk seluruh endpoint TheMealDB (API v1 publik,
/// tanpa kunci). Satu instance dipakai selama aplikasi berjalan.
class MealApi {
  MealApi({http.Client? client, Uri? baseUri, Duration? timeout})
    : _client = client ?? http.Client(),
      _baseUri =
          baseUri ?? Uri.parse('https://www.themealdb.com/api/json/v1/1/'),
      _timeout = timeout ?? const Duration(seconds: 15);

  final http.Client _client;
  final Uri _baseUri;
  final Duration _timeout;

  /// Mencari resep berdasarkan nama (`search.php?s=`). Respons berisi
  /// objek resep lengkap; list kosong berarti tidak ada hasil.
  Future<List<Meal>> searchMeals(String query) async {
    final decoded = await _getJson(_endpoint('search.php', {'s': query}));
    return _parseMealList(decoded);
  }

  /// Detail satu resep berdasarkan ID (`lookup.php?i=`).
  /// Mengembalikan null bila ID tidak dikenal.
  Future<Meal?> lookupMeal(String id) async {
    final decoded = await _getJson(_endpoint('lookup.php', {'i': id}));
    return _parseSingleMeal(decoded);
  }

  /// Satu resep acak (`random.php`). Bisa null pada respons anomali —
  /// layar wajib menanganinya sebagai error, bukan crash.
  Future<Meal?> randomMeal() async {
    final decoded = await _getJson(_endpoint('random.php'));
    return _parseSingleMeal(decoded);
  }

  /// Daftar kategori (`categories.php`).
  Future<List<MealCategory>> fetchCategories() async {
    final decoded = await _getJson(_endpoint('categories.php'));
    if (decoded is! Map<String, dynamic>) {
      throw const MealApiException(MealApiError.invalidResponse);
    }
    final categories = decoded['categories'];
    if (categories == null) return const [];
    if (categories is! List) {
      throw const MealApiException(MealApiError.invalidResponse);
    }
    return categories
        .whereType<Map<String, dynamic>>()
        .map(MealCategory.fromJson)
        .whereType<MealCategory>()
        .toList(growable: false);
  }

  /// Resep dalam satu kategori (`filter.php?c=`). Respons hanya memuat
  /// id, nama, dan gambar — jangan mengharapkan field detail di sini.
  Future<List<Meal>> filterByCategory(String category) async {
    final decoded = await _getJson(_endpoint('filter.php', {'c': category}));
    return _parseMealList(decoded);
  }

  void close() => _client.close();

  Uri _endpoint(String file, [Map<String, String>? query]) {
    final path = '${_baseUri.path}$file';
    if (query == null || query.isEmpty) {
      return _baseUri.replace(path: path);
    }
    return _baseUri.replace(path: path, queryParameters: query);
  }

  Future<Object?> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const MealApiException(MealApiError.network);
    } on http.ClientException {
      throw const MealApiException(MealApiError.network);
    } on IOException {
      throw const MealApiException(MealApiError.network);
    }

    if (response.statusCode != 200) {
      throw const MealApiException(MealApiError.server);
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const MealApiException(MealApiError.invalidResponse);
    }
  }

  /// Konvensi TheMealDB: `meals: null` berarti tidak ada hasil, bukan
  /// error. Entri tanpa id/nama dibuang karena tidak bisa dinavigasi.
  List<Meal> _parseMealList(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      throw const MealApiException(MealApiError.invalidResponse);
    }
    final meals = decoded['meals'];
    if (meals == null) return const [];
    if (meals is! List) {
      throw const MealApiException(MealApiError.invalidResponse);
    }
    return meals
        .whereType<Map<String, dynamic>>()
        .map(Meal.fromJson)
        .whereType<Meal>()
        .toList(growable: false);
  }

  Meal? _parseSingleMeal(Object? decoded) {
    final list = _parseMealList(decoded);
    return list.isEmpty ? null : list.first;
  }
}
