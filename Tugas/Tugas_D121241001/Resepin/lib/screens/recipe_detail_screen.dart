import 'package:flutter/material.dart';

import '../models/meal.dart';
import '../services/meal_api.dart';
import '../theme/app_theme.dart';
import '../widgets/error_block.dart';
import '../widgets/meal_image.dart';
import '../widgets/skeleton.dart';

/// Detail resep. Menerima data dari kartu asal: bila sudah lengkap
/// (search.php / random.php) langsung dipakai tanpa request kedua; bila
/// ringkas (filter.php) detail diambil via `lookup.php?i=`.
/// Di-push sebagai route terpisah — tanpa bottom navigation.
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.mealId,
    required this.heroTag,
    this.initialMeal,
  });

  final String mealId;
  final String heroTag;
  final Meal? initialMeal;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final MealApi _api = MealApi();

  Meal? _meal;
  bool _loading = false;
  bool _notFound = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMeal;
    if (initial != null && initial.hasFullDetail) {
      _meal = initial;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _notFound = false;
    });
    try {
      final meal = await _api.lookupMeal(widget.mealId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _meal = meal;
        _notFound = meal == null;
      });
    } on MealApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildContent(),
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(ResepinSpacing.sm),
              child: _BackButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResepinLayout.maxContentWidth,
          ),
          child: const _DetailSkeleton(),
        ),
      );
    }
    final error = _error;
    if (error != null) {
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResepinLayout.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(ResepinSpacing.lg),
              child: ErrorBlock(message: error, onRetry: _load),
            ),
          ),
        ),
      );
    }
    if (_notFound) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(ResepinSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Resep tidak ditemukan.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: ResepinSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final meal = _meal!;
    final metaParts = [
      meal.category,
      meal.originLabel,
    ].whereType<String>().where((text) => text.isNotEmpty).toList();
    final paragraphs = meal.instructionParagraphs;

    // Lebar konten dibatasi di layar besar (web/tablet) agar gambar dan
    // paragraf tetap pada ukuran yang nyaman.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ResepinLayout.maxContentWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.only(bottom: ResepinSpacing.xxl),
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(ResepinRadius.detailImage),
              ),
              child: Hero(
                tag: widget.heroTag,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: MealImage(url: meal.thumbnailUrl),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ResepinSpacing.lg,
                ResepinSpacing.xl,
                ResepinSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: ResepinSpacing.xs),
                    Text(
                      metaParts.join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (meal.ingredients.isNotEmpty) ...[
                    const SizedBox(height: ResepinSpacing.xl),
                    Text(
                      'Bahan (${meal.ingredients.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: ResepinSpacing.xs),
                    _IngredientList(ingredients: meal.ingredients),
                  ],
                  if (paragraphs.isNotEmpty) ...[
                    const SizedBox(height: ResepinSpacing.xl),
                    Text(
                      'Cara membuat',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: ResepinSpacing.sm),
                    for (final paragraph in paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: ResepinSpacing.md,
                        ),
                        child: Text(
                          paragraph,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol kembali melayang di atas gambar. Scrim gelap bulat memberi
/// kontras cukup terhadap foto apa pun (bukan dekorasi).
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: 'Kembali',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }
}

/// Daftar bahan dua kolom: takaran kiri (lebar tetap), nama kanan.
/// Takaran null berarti nama tampil penuh tanpa kolom ukuran.
/// Jarak antar kolom wajib ada — tanpa itu takaran panjang seperti
/// "1 finely sliced" menempel ke nama bahan ("...slicedOnion").
class _IngredientList extends StatelessWidget {
  const _IngredientList({required this.ingredients});

  final List<Ingredient> ingredients;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      children: [
        for (var i = 0; i < ingredients.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: ResepinSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ingredients[i].measure != null) ...[
                  SizedBox(
                    width: 104,
                    child: Text(
                      ingredients[i].measure!,
                      style: style?.copyWith(color: ResepinColors.inkMuted),
                    ),
                  ),
                  const SizedBox(width: ResepinSpacing.md),
                ],
                Expanded(child: Text(ingredients[i].name, style: style)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const AspectRatio(aspectRatio: 4 / 3, child: SkeletonBox(radius: 0)),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ResepinSpacing.lg,
            ResepinSpacing.xl,
            ResepinSpacing.lg,
            0,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 30),
              SizedBox(height: ResepinSpacing.md),
              SkeletonBox(width: 150, height: 14),
              SizedBox(height: ResepinSpacing.xl),
              SkeletonBox(width: 110, height: 18),
              SizedBox(height: ResepinSpacing.lg),
              SkeletonBox(height: 16),
              SizedBox(height: ResepinSpacing.sm),
              SkeletonBox(height: 16),
              SizedBox(height: ResepinSpacing.sm),
              SkeletonBox(width: 220, height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
