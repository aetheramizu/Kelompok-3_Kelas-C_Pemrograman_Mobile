import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../services/meal_api.dart';
import '../../theme/app_theme.dart';
import '../widgets/error_block.dart';
import '../widgets/search_result_tile.dart';
import '../widgets/skeleton.dart';
import 'recipe_detail_screen.dart';

/// Layar Cari: pencarian resep submit-driven — request hanya berjalan
/// saat tombol Search pada keyboard ditekan, tidak per perubahan huruf.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final MealApi _api = MealApi();
  final TextEditingController _controller = TextEditingController();

  List<Meal>? _results;
  String? _lastQuery;
  bool _loading = false;
  String? _error;

  /// Urutan request: respons dari query lama yang datang terlambat
  /// diabaikan agar tidak menimpa hasil query terbaru.
  int _requestSeq = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    // Input kosong atau hanya whitespace diabaikan: tetap di state awal.
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _runSearch(query);
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = query;
    });
    try {
      final meals = await _api.searchMeals(query);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = meals;
        _loading = false;
      });
    } on MealApiException catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  /// Buka detail. Hasil search.php sudah memuat instruksi lengkap, jadi
  /// layar detail memakai data ini tanpa request kedua.
  void _openDetail(Meal meal) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailScreen(
          mealId: meal.id,
          heroTag: 'search-${meal.id}',
          initialMeal: meal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              resepinGutter(context),
              ResepinSpacing.lg,
              resepinGutter(context),
              ResepinSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cari resep',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: ResepinSpacing.md),
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  // setState hanya untuk mengatur tampilnya tombol clear.
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Nama masakan atau bahan',
                    prefixIcon: Semantics(
                      excludeSemantics: true,
                      child: const Icon(Icons.search),
                    ),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan pencarian',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _controller.clear();
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _SearchSkeletonList();
    final error = _error;
    if (error != null) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: resepinGutter(context),
            vertical: ResepinSpacing.lg,
          ),
          child: ErrorBlock(
            message: error,
            onRetry: () => _runSearch(_lastQuery!),
          ),
        ),
      );
    }
    final results = _results;
    if (results == null) return const _HelpState();
    if (results.isEmpty) return _EmptyResults(query: _lastQuery ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            resepinGutter(context),
            0,
            resepinGutter(context),
            ResepinSpacing.md,
          ),
          child: Text(
            'Hasil untuk "${_lastQuery ?? ''}"',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              resepinGutter(context),
              0,
              resepinGutter(context),
              ResepinSpacing.lg,
            ),
            itemCount: results.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: ResepinSpacing.md),
            itemBuilder: (context, index) => SearchResultTile(
              key: ValueKey(results[index].id),
              meal: results[index],
              heroTag: 'search-${results[index].id}',
              onTap: () => _openDetail(results[index]),
            ),
          ),
        ),
      ],
    );
  }
}

/// State awal: satu kalimat bantuan, tanpa chip atau data palsu.
class _HelpState extends StatelessWidget {
  const _HelpState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ResepinSpacing.lg),
        child: Text(
          'Ketik nama masakan atau bahan, lalu tekan cari.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ResepinSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tidak ada hasil untuk "$query"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: ResepinSpacing.xs),
            Text(
              'Coba kata kunci lain, misalnya nama masakan atau bahan '
              'utama.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSkeletonList extends StatelessWidget {
  const _SearchSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: resepinGutter(context),
        vertical: ResepinSpacing.lg,
      ),
      child: const Column(
        children: [
          _SkeletonTile(),
          SizedBox(height: ResepinSpacing.md),
          _SkeletonTile(),
          SizedBox(height: ResepinSpacing.md),
          _SkeletonTile(),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ResepinDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: const Padding(
        padding: EdgeInsets.all(ResepinSpacing.md),
        child: Row(
          children: [
            SkeletonBox(width: 72, height: 72, radius: ResepinRadius.chip),
            SizedBox(width: ResepinSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonBox(height: 18),
                  SizedBox(height: ResepinSpacing.sm),
                  SkeletonBox(width: 130, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
