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

  // Ricerca remota su Open Food Facts: solo su richiesta esplicita
  List<OffProduct>? _offResults;
  bool _offLoading = false;
  String? _offError;
  String? _importingBarcode;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _searchOff() async {
    final query = _query;
    setState(() {
      _offLoading = true;
      _offError = null;
    });
    try {
      final results = await FoodService.searchOff(query);
      if (mounted && query == _query) setState(() => _offResults = results);
    } on AppError catch (e) {
      if (mounted && query == _query) setState(() => _offError = e.message);
    } finally {
      if (mounted && query == _query) setState(() => _offLoading = false);
    }
  }

  /// Importa il prodotto nel catalogo locale e apre il record locale.
  Future<void> _importOff(OffProduct product) async {
    setState(() => _importingBarcode = product.barcode);
    try {
      final food = await FoodService.getFoodByBarcode(product.barcode!);
      if (!mounted) return;
      if (food == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prodotto non disponibile.')));
        return;
      }
      await _open(food);
    } on AppError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _importingBarcode = null);
    }
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _query = value.trim();
    _offResults = null;
    _offError = null;
    _offLoading = false;
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (_results.isEmpty && !_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nessun alimento nel catalogo', textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
          ),
        for (final food in _results) ...[
          _tile(
            title: food.name,
            subtitle: [if (food.subtitle.isNotEmpty) food.subtitle, '${food.kcal.round()} kcal / 100 g'].join(' · '),
            trailing: food.isVerified
                ? const Icon(Icons.verified_outlined, color: primaryTeal, size: 18)
                : const Icon(Icons.chevron_right, color: textSecondary),
            onTap: () => _open(food),
          ),
          const SizedBox(height: 8),
        ],
        if (!_loading) ..._buildOffSection(),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildOffSection() {
    if (_offResults == null) {
      return [
        TextButton.icon(
          onPressed: _offLoading ? null : _searchOff,
          icon: _offLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: primaryTeal))
              : const Icon(Icons.travel_explore, color: primaryTeal),
          label: const Text('Non trovi il prodotto? Cerca su Open Food Facts', style: TextStyle(color: primaryTeal)),
        ),
        if (_offError != null)
          Text(_offError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
      ];
    }
    return [
      const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 8),
        child: Text('Da Open Food Facts', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
      ),
      if (_offResults!.isEmpty)
        const Text('Nessun prodotto trovato.', style: TextStyle(color: textSecondary)),
      for (final p in _offResults!) ...[
        _tile(
          title: p.name,
          subtitle: [if (p.brand?.isNotEmpty ?? false) p.brand!, '${p.kcal.round()} kcal / 100 g'].join(' · '),
          trailing: _importingBarcode == p.barcode
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primaryTeal))
              : const Icon(Icons.download_outlined, color: textSecondary),
          onTap: _importingBarcode == null ? () => _importOff(p) : null,
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _tile({required String title, required String subtitle, required Widget trailing, VoidCallback? onTap}) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: textSecondary)),
        trailing: trailing,
      ),
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
