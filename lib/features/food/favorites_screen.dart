import 'package:flutter/material.dart';
import '../../core/food_service.dart';
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

  List<Map<String, dynamic>> _favoriteFoods = [];
  bool _isLoading = true; 

  @override
  void initState() {
    super.initState();
    _loadDataFromDatabase();
  }

  Future<void> _loadDataFromDatabase() async {
    final data = await FoodService.getUserFavorites(); 
    if (mounted) {
      setState(() {
        _favoriteFoods = data;
        _isLoading = false; 
      });
    }
  }

  List<Map<String, dynamic>> get _filteredFoods {
    List<Map<String, dynamic>> filteredList = List.from(_favoriteFoods);
    
    if (_selectedFilterIndex == 1) { 
      filteredList.sort((a, b) => (b['usage'] ?? 0).compareTo(a['usage'] ?? 0));
    } else if (_selectedFilterIndex == 2) { 
      filteredList.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
    }

    filteredList.sort((a, b) {
      bool aFav = a['isFavorite'] ?? false;
      bool bFav = b['isFavorite'] ?? false;
      if (aFav && !bFav) return -1; 
      if (!aFav && bFav) return 1;  
      return 0; 
    });
    
    return filteredList;
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
            onPressed: () {
              showSearch(context: context, delegate: FoodSearchDelegate(colorP, colorC, colorG, primaryTeal))
                .then((_) => _loadDataFromDatabase());
            }
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, 
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
              : _filteredFoods.isEmpty
                  ? const Center(child: Text('Nessun alimento trovato', style: TextStyle(color: textSecondary)))
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

  Widget _buildFoodCard(Map<String, dynamic> food) {
    final bool isVerified = food['verified'] ?? false;
    final bool isFavorite = food['isFavorite'] ?? false;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => FoodDetailScreen(foodData: food)))
            .then((_) => _loadDataFromDatabase());
      },
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
                      if (isFavorite)
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
                    '${food['name']} · ${food['brand']}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary), 
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      _buildMacroPill('P', '${food['p']}g', colorP, bgP),
                      const SizedBox(width: 6),
                      _buildMacroPill('C', '${food['c']}g', colorC, bgC),
                      const SizedBox(width: 6),
                      _buildMacroPill('G', '${food['g']}g', colorG, bgG),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${food['kcal']} kcal', style: const TextStyle(color: textSecondary, fontSize: 12)),
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

  Widget _buildVerificationBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: isVerified ? const Color(0xFFE6F4F1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(isVerified ? Icons.verified_outlined : Icons.info_outline, size: 12, color: isVerified ? primaryTeal : textSecondary),
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
    if (query.isEmpty) return const Center(child: Text('Inizia a digitare per cercare.'));
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FoodService.searchFoods(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: primaryTeal));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nessun risultato trovato.'));

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final food = snapshot.data![index];
            return ListTile(
              leading: const Icon(Icons.restaurant),
              title: Text(food['name']),
              subtitle: Text('${food['kcal']} kcal - ${food['brand']}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => FoodDetailScreen(foodData: food)))
                  .then((_) => close(context, null)); 
              },
            );
          },
        );
      },
    );
  }
}