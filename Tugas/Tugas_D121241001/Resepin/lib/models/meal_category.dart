/// Kategori dari `categories.php`. [imageUrl] dan [description] tidak
/// dipakai chip MVP, tetap disimpan agar model setia pada respons API.
class MealCategory {
  const MealCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final String? description;

  /// Mengembalikan null bila id atau nama kosong (entri tidak valid).
  static MealCategory? fromJson(Map<String, dynamic> json) {
    final id = json['idCategory']?.toString().trim() ?? '';
    final name = (json['strCategory'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) return null;

    final thumb = (json['strCategoryThumb'] as String?)?.trim() ?? '';
    final description =
        (json['strCategoryDescription'] as String?)?.trim() ?? '';

    return MealCategory(
      id: id,
      name: name,
      imageUrl: thumb.isEmpty ? null : thumb,
      description: description.isEmpty ? null : description,
    );
  }
}
