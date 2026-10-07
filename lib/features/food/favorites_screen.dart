
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/app_error.dart';
import '../../core/food_service.dart';
import '../../core/models.dart';
import 'food_detail_screen.dart';
import 'search_food_screen.dart';
import '../../core/widgets/custom_bottom_nav.dart';
import '../shell/patient_shell.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with ReloadOnTabVisible {
  static const _mealsFilter = 3;

  @override
  int get tabIndex => PatientTab.foods;

  @override
  void onTabVisible() => _loadDataFromDatabase();

  
  

  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Tutti', 'Più usati', 'Recenti', 'Pasti salvati'];

  List<FavoriteFood> _favoriteFoods = [];
  List<PersonalMeal> _personalMeals = [];
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
      final results = await Future.wait([FoodService.getFavorites(), FoodService.getPersonalMeals()]);
      if (mounted) {
        setState(() {
          _favoriteFoods = results[0] as List<FavoriteFood>;
          _personalMeals = results[1] as List<PersonalMeal>;
        });
      }
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
    context.watchTheme();
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catalogo', style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
            Text('I tuoi alimenti e preferiti', style: TextStyle(color: textSecondary, fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: textPrimary), 
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
      bottomNavigationBar: CustomBottomNav(currentIndex: PatientTab.foods),

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
                    backgroundColor: cardColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? primaryTeal : borderColor),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryTeal))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: textSecondary)),
                          TextButton(onPressed: _loadDataFromDatabase, child: Text('Riprova', style: TextStyle(color: primaryTeal))),
                        ],
                      ),
                    )
              : _selectedFilterIndex == _mealsFilter
                  ? _buildPersonalMeals()
              : _filteredFoods.isEmpty
                  ? Center(child: Text('Nessun preferito. Cerca un alimento e salvalo.', style: TextStyle(color: textSecondary)))
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

  Widget _buildPersonalMeals() {
    if (_personalMeals.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nessun pasto salvato.\nNel diario tieni premuto su un pasto per salvarlo e riusarlo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _personalMeals.length,
      itemBuilder: (context, index) {
        final meal = _personalMeals[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: ListTile(
            leading: Icon(Icons.bookmark_outline, color: primaryTeal),
            title: Text(meal.name, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
            subtitle: Text(
              [if (meal.defaultSlot != null) meal.defaultSlot!.label, 'usato ${meal.useCount} volte'].join(' · '),
              style: TextStyle(color: textSecondary),
            ),
            trailing: IconButton(
              tooltip: 'Elimina',
              icon: Icon(Icons.delete_outline, color: textSecondary),
              onPressed: () => _deletePersonalMeal(meal),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePersonalMeal(PersonalMeal meal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminare "${meal.name}"?'),
        content: const Text('Le voci già registrate nel diario restano.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FoodService.deletePersonalMeal(meal.id);
      if (mounted) setState(() => _personalMeals = _personalMeals.where((m) => m.id != meal.id).toList());
    } on AppError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Una sola ricerca in tutta l'app: quella di [SearchFoodScreen], con
  /// filtri nutrizionali, catalogo esteso e import da codice a barre.
  /// Qui si apre senza pasto di destinazione, perché si sta consultando
  /// il catalogo e non registrando un pasto.
  void _openSearch() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchFoodScreen()))
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
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(12)),
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
                         Icon(Icons.verified_outlined, size: 16, color: primaryTeal),
                    ],
                  ),
                  
                  Text(
                    [food.name, if (food.brandLabel != null) food.brandLabel!, '$grams g'].join(' · '),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
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
                  Text('${(food.kcal * ratio).round()} kcal', style: TextStyle(color: textSecondary, fontSize: 12)),
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
