import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/app_error.dart';
import '../../core/food_service.dart';
import '../../core/models.dart';
import 'food_detail_screen.dart';
import '../../core/widgets/custom_bottom_nav.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  
  static const Color colorP = Color(0xFF5A44F2);
  static const Color colorC = Color(0xFFF0A500);
  static const Color colorG = Color(0xFFEB5A0C);
  
  static const Color bgP = Color(0xFFF0EFFF);
  static const Color bgC = Color(0xFFFEF6E5);
  static const Color bgG = Color(0xFFFDEEE6);

  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Tutti', 'Più usati', 'Recenti'];

  List<FavoriteFood> _favoriteFoods = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDataFromDatabase();
  }

  Future<void> _loadDataFromDatabase() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await FoodService.getFavorites();
      if (mounted) setState(() => _favoriteFoods = data);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<FavoriteFood> get _filteredFoods {
    final filteredList = List<FavoriteFood>.from(_favoriteFoods);

    if (_selectedFilterIndex == 1) {
      filteredList.sort((a, b) => b.useCount.compareTo(a.useCount));
    } else if (_selectedFilterIndex == 2) {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      filteredList.sort((a, b) => (b.lastUsedAt ?? epoch).compareTo(a.lastUsedAt ?? epoch));
    }

    return filteredList;
  }

  void _openFood(Food food, {double? grams}) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => FoodDetailScreen(food: food, initialGrams: grams)))
        .then((_) => _loadDataFromDatabase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catalogo', style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
            Text('I tuoi alimenti e preferiti', style: TextStyle(color: textSecondary, fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: textPrimary), 
            onPressed: _openSearch,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSearch,
        backgroundColor: primaryTeal,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNav(currentIndex: 1, isDarkMode: false),

      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedFilterIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(_filters[index]),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedFilterIndex = index);
                    },
                    selectedColor: primaryTeal,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? primaryTeal : Colors.grey.shade300),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: primaryTeal))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: textSecondary)),
                          TextButton(onPressed: _loadDataFromDatabase, child: const Text('Riprova', style: TextStyle(color: primaryTeal))),
                        ],
                      ),
                    )
              : _filteredFoods.isEmpty
                  ? const Center(child: Text('Nessun preferito. Cerca un alimento e salvalo.', style: TextStyle(color: textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filteredFoods.length,
                      itemBuilder: (context, index) {
                        return _buildFoodCard(_filteredFoods[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _openSearch() {
    showSearch(context: context, delegate: FoodSearchDelegate(colorP, colorC, colorG, primaryTeal))
        .then((_) => _loadDataFromDatabase());
  }

  Widget _buildFoodCard(FavoriteFood favorite) {
    final food = favorite.food;
    final bool isVerified = food.isVerified;
    // Macro mostrati sulla porzione abituale salvata nel preferito
    final ratio = favorite.defaultGrams / 100.0;
    final grams = favorite.defaultGrams.round();

    return GestureDetector(
      onTap: () => _openFood(food, grams: favorite.defaultGrams),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.restaurant, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                          margin: const EdgeInsets.only(right: 6, bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Icon(Icons.favorite, size: 10, color: Colors.red.shade400),
                              const SizedBox(width: 2),
                              Text('Preferito', style: TextStyle(color: Colors.red.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      if (isVerified)
                         const Icon(Icons.verified_outlined, size: 16, color: primaryTeal),
                    ],
                  ),
                  
                  Text(
                    [food.name, if (food.brand?.isNotEmpty ?? false) food.brand!, '$grams g'].join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      _buildMacroPill('P', '${(food.proteinG * ratio).round()}g', colorP, bgP),
                      const SizedBox(width: 6),
                      _buildMacroPill('C', '${(food.carbsG * ratio).round()}g', colorC, bgC),
                      const SizedBox(width: 6),
                      _buildMacroPill('G', '${(food.fatG * ratio).round()}g', colorG, bgG),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${(food.kcal * ratio).round()} kcal', style: const TextStyle(color: textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: primaryTeal, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroPill(String label, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: textColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('$label $value', style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class FoodSearchDelegate extends SearchDelegate {
  final Color colorP, colorC, colorG, primaryTeal;
  FoodSearchDelegate(this.colorP, this.colorC, this.colorG, this.primaryTeal);

  @override
  String get searchFieldLabel => 'Cerca un alimento...';

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.trim().length < 2) return const Center(child: Text('Inizia a digitare per cercare.'));
    return _DebouncedFoodResults(
      query: query.trim(),
      primaryTeal: primaryTeal,
      onSelected: (context, food) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => FoodDetailScreen(food: food)))
            .then((_) {
          if (context.mounted) close(context, null);
        });
      },
    );
  }
}

/// Risultati di ricerca con debounce: una sola RPC dopo che l'utente
/// smette di digitare, non una per tasto.
class _DebouncedFoodResults extends StatefulWidget {
  final String query;
  final Color primaryTeal;
  final void Function(BuildContext context, Food food) onSelected;

  const _DebouncedFoodResults({required this.query, required this.primaryTeal, required this.onSelected});

  @override
  State<_DebouncedFoodResults> createState() => _DebouncedFoodResultsState();
}

class _DebouncedFoodResultsState extends State<_DebouncedFoodResults> {
  Timer? _timer;
  List<Food>? _results;
  String? _error;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(_DebouncedFoodResults old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search() async {
    final query = widget.query;
    setState(() {
      _results = null;
      _error = null;
    });
    try {
      final results = await FoodService.searchFoods(query);
      if (mounted && query == widget.query) setState(() => _results = results);
    } on AppError catch (e) {
      if (mounted && query == widget.query) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _search, child: Text('Riprova', style: TextStyle(color: widget.primaryTeal))),
          ],
        ),
      );
    }
    final results = _results;
    if (results == null) return Center(child: CircularProgressIndicator(color: widget.primaryTeal));
    if (results.isEmpty) return const Center(child: Text('Nessun risultato trovato.'));

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final food = results[index];
        return ListTile(
          leading: const Icon(Icons.restaurant),
          title: Text(food.name),
          subtitle: Text([
            '${food.kcal.round()} kcal / 100 g',
            if (food.brand?.isNotEmpty ?? false) food.brand!,
          ].join(' - ')),
          trailing: food.isVerified
              ? Icon(Icons.verified_outlined, color: widget.primaryTeal)
              : const Icon(Icons.chevron_right),
          onTap: () => widget.onSelected(context, food),
        );
      },
    );
  }
}