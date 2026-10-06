import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/food_service.dart';
import '../../core/models.dart';
import 'food_detail_screen.dart';

/// Ricerca nel catalogo locale. Restituisce `true` se un alimento è stato
/// aggiunto al diario.
class SearchFoodScreen extends StatefulWidget {
  final MealSlot slot;
  final DateTime date;

  const SearchFoodScreen({super.key, required this.slot, required this.date});

  @override
  State<SearchFoodScreen> createState() => _SearchFoodScreenState();
}

class _SearchFoodScreenState extends State<SearchFoodScreen> {
  // Colori del tuo tema
  static const Color bgColor = Color(0xFF101817);
  static const Color cardColor = Color(0xFF17221F);
  static const Color textSecondary = Color(0xFFA1AFA9);
  static const Color primaryTeal = Color(0xFF127B6D);

  static const _debounce = Duration(milliseconds: 500);

  Timer? _timer;
  String _query = '';
  bool _loading = false;
  String? _error;
  List<Food> _results = [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _query = value.trim();
    if (_query.length < 2) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _timer = Timer(_debounce, () => _search(_query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await FoodService.searchFoods(query);
      if (!mounted || query != _query) return;
      setState(() => _results = results);
    } on AppError catch (e) {
      if (!mounted || query != _query) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted && query == _query) setState(() => _loading = false);
    }
  }

  Future<void> _open(Food food) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(food: food, initialSlot: widget.slot, date: widget.date),
      ),
    );
    if (added == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Aggiungi a ${widget.slot.label}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barra di ricerca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              autofocus: true, // Apre subito la tastiera
              decoration: InputDecoration(
                hintText: 'Cerca un alimento...',
                hintStyle: const TextStyle(color: textSecondary),
                prefixIcon: const Icon(Icons.search, color: textSecondary),
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading) const LinearProgressIndicator(color: primaryTeal, backgroundColor: cardColor),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildMessage(Icons.cloud_off, _error!, action: TextButton(
        onPressed: () => _search(_query),
        child: const Text('Riprova', style: TextStyle(color: primaryTeal)),
      ));
    }
    if (_query.length < 2) return _buildMessage(Icons.restaurant_menu, 'Cerca un alimento da aggiungere');
    if (_results.isEmpty && !_loading) return _buildMessage(Icons.search_off, 'Nessun alimento trovato');

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final food = _results[index];
        return Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onTap: () => _open(food),
            title: Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              [if (food.subtitle.isNotEmpty) food.subtitle, '${food.kcal.round()} kcal / 100 g'].join(' · '),
              style: const TextStyle(color: textSecondary),
            ),
            trailing: food.isVerified
                ? const Icon(Icons.verified_outlined, color: primaryTeal, size: 18)
                : const Icon(Icons.chevron_right, color: textSecondary),
          ),
        );
      },
    );
  }

  Widget _buildMessage(IconData icon, String text, {Widget? action}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: textSecondary),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: textSecondary, fontSize: 16)),
          ?action,
        ],
      ),
    );
  }
}
