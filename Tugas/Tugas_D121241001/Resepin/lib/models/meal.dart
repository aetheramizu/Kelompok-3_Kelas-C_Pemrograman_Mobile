/// Satu bahan resep, hasil transformasi pasangan field
/// `strIngredient{n}` / `strMeasure{n}` dari respons API.
class Ingredient {
  const Ingredient({required this.name, this.measure});

  final String name;

  /// Takaran bahan; null bila API tidak menyediakannya.
  final String? measure;
}

/// Data resep TheMealDB. Satu model menampung bentuk ringkas (hasil
/// `filter.php`: id, nama, gambar) maupun lengkap (`search.php`,
/// `lookup.php`, `random.php`). Field yang tidak dikirim API tetap null
/// dan tidak pernah dikarang.
class Meal {
  const Meal({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.category,
    this.area,
    this.country,
    this.instructions,
    this.ingredients = const [],
  });

  final String id;
  final String name;
  final String? thumbnailUrl;
  final String? category;

  /// Bisa null — terverifikasi pada respons random.php.
  final String? area;

  /// Field pendamping [area]; keduanya bisa null sekaligus.
  final String? country;
  final String? instructions;

  /// Kosong untuk bentuk ringkas; terisi untuk bentuk lengkap.
  final List<Ingredient> ingredients;

  /// Detail dianggap lengkap bila API menyertakan instruksi. Hasil
  /// filter.php tidak memilikinya, jadi layar detail perlu lookup.
  bool get hasFullDetail =>
      instructions != null && instructions!.trim().isNotEmpty;

  /// Instruksi dipecah menjadi paragraf: pemisah `\r\n` dari API, tiap
  /// baris di-trim, baris kosong dibuang. Tanpa penomoran artifisial.
  List<String> get instructionParagraphs {
    final raw = instructions;
    if (raw == null) return const [];
    return raw
        .split(RegExp(r'\r\n|\r|\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  /// Label asal masakan untuk meta: gunakan [area], bila kosong turun ke
  /// [country], dan tetap null bila keduanya tidak ada.
  String? get originLabel {
    final a = area;
    if (a != null && a.isNotEmpty) return a;
    final c = country;
    if (c != null && c.isNotEmpty) return c;
    return null;
  }

  /// Parsing null-safe dari satu objek meal API. Mengembalikan null bila
  /// id atau nama kosong — entri seperti itu tidak bisa dipakai navigasi.
  static Meal? fromJson(Map<String, dynamic> json) {
    final id = _clean(json['idMeal']);
    final name = _clean(json['strMeal']);
    if (id.isEmpty || name.isEmpty) return null;

    return Meal(
      id: id,
      name: name,
      thumbnailUrl: _nullIfEmpty(_clean(json['strMealThumb'])),
      category: _nullIfEmpty(_clean(json['strCategory'])),
      area: _nullIfEmpty(_clean(json['strArea'])),
      country: _nullIfEmpty(_clean(json['strCountry'])),
      // Instruksi tidak di-collapse agar pemisah baris untuk paragraf
      // tetap utuh; hanya ujungnya yang di-trim.
      instructions: _nullIfEmpty(
        (json['strInstructions'] as String?)?.trim() ?? '',
      ),
      ingredients: _parseIngredients(json),
    );
  }

  /// Iterasi pasangan strIngredient1..20 dan strMeasure1..20. Baris tanpa
  /// nama bahan dibuang (termasuk celah di tengah), takaran kosong menjadi
  /// null sehingga UI menampilkan nama bahan saja.
  static List<Ingredient> _parseIngredients(Map<String, dynamic> json) {
    final result = <Ingredient>[];
    for (var i = 1; i <= 20; i++) {
      final name = _clean(json['strIngredient$i']);
      if (name.isEmpty) continue;
      final measure = _clean(json['strMeasure$i']);
      result.add(Ingredient(name: name, measure: _nullIfEmpty(measure)));
    }
    return result;
  }

  static String _clean(Object? value) {
    return (value?.toString() ?? '').trim().replaceAll(_whitespace, ' ');
  }

  static String? _nullIfEmpty(String text) => text.isEmpty ? null : text;

  static final RegExp _whitespace = RegExp(r'\s+');
}
