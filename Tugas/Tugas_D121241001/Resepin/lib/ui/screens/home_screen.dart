import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../models/meal_category.dart';
import '../../services/meal_api.dart';
import '../../theme/app_theme.dart';
import '../widgets/category_chips.dart';
import '../widgets/error_block.dart';
import '../widgets/random_recipe_card.dart';
import '../widgets/recipe_grid.dart';
import '../widgets/skeleton.dart';
import 'recipe_detail_screen.dart';

/// Beranda: header editorial, kartu rekomendasi acak, baris chip kategori,
/// dan grid resep dua kolom per kategori aktif. Kategori awal mengikuti
/// item pertama yang dikirim `categories.php` — tidak ada yang di-hardcode.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MealApi _api = MealApi();
  final GlobalKey _gridSectionKey = GlobalKey();

  List<MealCategory>? _categories;
  bool _categoriesLoading = true;
  String? _categoriesError;
  String? _activeCategory;

  List<Meal>? _meals;
  bool _gridLoading = false;
  String? _gridError;

  Meal? _randomMeal;
  bool _randomRefreshing = true;
  String? _randomError;

  /// Urutan request grid. Respons lama yang datang setelah pengguna
  /// mengetuk chip lain diabaikan agar tidak menimpa hasil terbaru.
  int _gridRequestSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _refreshRandom();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _categoriesLoading = true;
      _categoriesError = null;
    });
    try {
      final categories = await _api.fetchCategories();
      if (!mounted) return;
      if (categories.isEmpty) {
        setState(() {
          _categoriesLoading = false;
          _categoriesError = 'Kategori tidak tersedia.';
        });
        return;
      }
      setState(() {
        _categories = categories;
        _categoriesLoading = false;
        _activeCategory ??= categories.first.name;
      });
      _loadGrid(_activeCategory!);
    } on MealApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _categoriesLoading = false;
        _categoriesError = e.message;
      });
    }
  }

  Future<void> _refreshRandom() async {
    setState(() => _randomRefreshing = true);
    try {
      final meal = await _api.randomMeal();
      if (!mounted) return;
      setState(() {
        _randomRefreshing = false;
        if (meal != null) {
          _randomMeal = meal;
        } else if (_randomMeal == null) {
          // Respons anomali tanpa meal: hanya jadi error bila belum ada
          // resep yang tampil; resep lama tetap dipertahankan.
          _randomError = 'Rekomendasi tidak tersedia.';
        }
      });
    } on MealApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _randomRefreshing = false;
        if (_randomMeal == null) _randomError = e.message;
      });
    }
  }

  Future<void> _loadGrid(String category) async {
    final seq = ++_gridRequestSeq;
    setState(() {
      _gridLoading = true;
      _gridError = null;
    });
    try {
      final meals = await _api.filterByCategory(category);
      if (!mounted || seq != _gridRequestSeq) return;
      setState(() {
        _meals = meals;
        _gridLoading = false;
      });
    } on MealApiException catch (e) {
      if (!mounted || seq != _gridRequestSeq) return;
      setState(() {
        _gridLoading = false;
        _gridError = e.message;
      });
    }
  }

  void _onCategorySelected(String name) {
    if (name == _activeCategory) return;
    setState(() => _activeCategory = name);
    _loadGrid(name);
    // Setelah kategori berganti, pastikan bagian grid terlihat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gridContext = _gridSectionKey.currentContext;
      if (gridContext != null) {
        Scrollable.ensureVisible(
          gridContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Buka detail. Hero tag diberi prefiks sumber ("home-random"/"home-grid")
  /// agar transisi tidak bertabrakan antar kartu dan antar layar.
  void _openDetail(Meal meal, String heroPrefix) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailScreen(
          mealId: meal.id,
          heroTag: '$heroPrefix-${meal.id}',
          initialMeal: meal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          resepinGutter(context),
          ResepinSpacing.lg,
          resepinGutter(context),
          ResepinSpacing.xl,
        ),
        children: [
          Text('Resepin', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: ResepinSpacing.xs),
          Text(
            'Mau masak apa hari ini?',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: ResepinSpacing.lg),
          RandomRecipeCard(
            meal: _randomMeal,
            refreshing: _randomRefreshing,
            errorMessage: _randomError,
            heroTag: 'home-random-${_randomMeal?.id ?? ''}',
            onRetry: _refreshRandom,
            onRefresh: _refreshRandom,
            onTap: () {
              final meal = _randomMeal;
              if (meal != null) _openDetail(meal, 'home-random');
            },
          ),
          const SizedBox(height: ResepinSpacing.xl),
          Text('Kategori', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: ResepinSpacing.md),
          _buildCategorySection(),
          const SizedBox(height: ResepinSpacing.xl),
          if (_activeCategory != null) ...[
            Container(
              key: _gridSectionKey,
              alignment: Alignment.centerLeft,
              child: Text(
                'Resep $_activeCategory',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: ResepinSpacing.md),
          ],
          _buildGridSection(),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    // ListView induk sudah menerapkan gutter layar; jangan menambah padding
    // horizontal lagi di sini (dulu dobel → chip hilang di layar lebar).
    if (_categoriesLoading) {
      // 56 = chip 48 + ruang indikator gulir 8, agar tinggi sama dengan
      // baris chip yang sudah termuat (tidak ada lompatan layout).
      return const SizedBox(
        height: 56,
        child: Row(
          children: [
            SkeletonBox(width: 88, height: 48, radius: ResepinRadius.chip),
            SizedBox(width: ResepinSpacing.sm),
            SkeletonBox(width: 110, height: 48, radius: ResepinRadius.chip),
            SizedBox(width: ResepinSpacing.sm),
            SkeletonBox(width: 96, height: 48, radius: ResepinRadius.chip),
          ],
        ),
      );
    }
    final error = _categoriesError;
    if (error != null) {
      return ErrorBlock(message: error, onRetry: _loadCategories);
    }
    return CategoryChips(
      categories: _categories!,
      selected: _activeCategory ?? '',
      onSelected: _onCategorySelected,
    );
  }

  Widget _buildGridSection() {
    if (_categoriesLoading) return const _GridSkeleton();
    if (_gridLoading) return const _GridSkeleton();
    final error = _gridError;
    if (error != null) {
      return ErrorBlock(
        message: error,
        onRetry: () => _loadGrid(_activeCategory!),
      );
    }
    final meals = _meals;
    if (meals == null || meals.isEmpty) {
      return const _EmptyMessage('Belum ada resep untuk kategori ini.');
    }
    return RecipeGrid(
      meals: meals,
      onMealTap: (meal) => _openDetail(meal, 'home-grid'),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SkeletonCardRow(),
        SizedBox(height: ResepinSpacing.md),
        _SkeletonCardRow(),
      ],
    );
  }
}

class _SkeletonCardRow extends StatelessWidget {
  const _SkeletonCardRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _SkeletonGridCard()),
        SizedBox(width: ResepinSpacing.md),
        Expanded(child: _SkeletonGridCard()),
      ],
    );
  }
}

class _SkeletonGridCard extends StatelessWidget {
  const _SkeletonGridCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ResepinDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 4 / 3, child: SkeletonBox(radius: 0)),
          Padding(
            padding: EdgeInsets.all(ResepinSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 18),
                SizedBox(height: ResepinSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SkeletonBox(width: 96, height: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ResepinSpacing.lg),
      child: Center(
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
