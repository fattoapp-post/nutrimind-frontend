import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/food_service.dart';
import '../../core/models.dart';
import '../nutritionist/create_food_screen.dart';
import 'food_detail_screen.dart';
import 'nutrient_filters_sheet.dart';

/// Ricerca nel catalogo, con filtri nutrizionali, catalogo esteso e
/// import da codice a barre. Restituisce `true` se un alimento è stato
/// aggiunto al diario.
///
/// Senza [slot] funziona da semplice consultazione del catalogo: il pasto
/// lo si sceglie, se serve, dal dettaglio dell'alimento.
class SearchFoodScreen extends StatefulWidget {
  final MealSlot? slot;
  final DateTime? date;

  const SearchFoodScreen({super.key, this.slot, this.date});

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
  NutrientFilters _filters = NutrientFilters.none;

  // Database esteso (Edge search-off): parte da solo, una volta per ricerca,
  // quando il catalogo locale dà pochi risultati
  static const _extendedThreshold = 5;
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
      // I filtri non si applicano al catalogo esterno: si filtra qui
      final filtered = _filters.hasBounds ? results.where((p) => p.matches(_filters)).toList() : results;
      if (mounted && query == _query) setState(() => _offResults = filtered);
    } on AppError catch (e) {
      if (mounted && query == _query) setState(() => _offError = e.message);
    } finally {
      if (mounted && query == _query) setState(() => _offLoading = false);
    }
  }

  static final _barcodePattern = RegExp(r'^[0-9]{8,14}$');

  /// L'utente ha digitato un codice a barre non in catalogo: lo importa.
  Future<void> _importByBarcode(String barcode) async {
    setState(() => _importingBarcode = barcode);
    try {
      final food = await FoodService.getFoodByBarcode(barcode);
      if (!mounted || barcode != _query) return;
      if (food == null) {
        setState(() => _offResults = const []);
        return;
      }
      await _open(food);
    } on AppError catch (e) {
      if (mounted && barcode == _query) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _importingBarcode = null);
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

  Future<void> _createPersonalFood() async {
    final food = await Navigator.push<Food>(
      context,
      MaterialPageRoute(builder: (_) => CreateFoodScreen(personal: true, initialName: _query)),
    );
    if (food != null && mounted) await _open(food);
  }

  /// Si cerca con almeno 2 caratteri, oppure con i soli filtri nutrizionali.
  bool get _canSearch => _query.length >= 2 || _filters.hasBounds;

  void _onChanged(String value) {
    _timer?.cancel();
    _query = value.trim();
    _offResults = null;
    _offError = null;
    _offLoading = false;
    if (!_canSearch) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _timer = Timer(_debounce, () => _search(_query));
  }

  Future<void> _openFilters() async {
    final filters = await NutrientFiltersSheet.show(context, _filters);
    if (filters == null || !mounted) return;
    setState(() {
      _filters = filters;
      _offResults = null;
      _offError = null;
    });
    if (_canSearch) {
      _search(_query);
    } else {
      setState(() => _results = []);
    }
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await FoodService.searchFoods(query, filters: _filters);
      if (!mounted || query != _query) return;
      setState(() => _results = results);
      // Un codice a barre digitato a mano: si importa come con lo scanner
      if (results.isEmpty && !_filters.hasBounds && _barcodePattern.hasMatch(query)) {
        _importByBarcode(query);
        return;
      }
      // Catalogo esteso: solo su ricerca testuale, serve il nome del prodotto
      if (results.length < _extendedThreshold && query.length >= 3 && _offResults == null) {
        _searchOff();
      }
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
          widget.slot == null ? 'Cerca un alimento' : 'Aggiungi a ${widget.slot!.label}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barra di ricerca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _filters.isActive ? primaryTeal : cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    tooltip: 'Filtri nutrizionali',
                    onPressed: _openFilters,
                    icon: Badge(
                      isLabelVisible: _filters.activeCount > 0,
                      label: Text('${_filters.activeCount}'),
                      child: Icon(Icons.tune, color: _filters.isActive ? Colors.white : textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_filters.isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_filters.summary, style: const TextStyle(color: primaryTeal, fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filters = NutrientFilters.none;
                        _offResults = null;
                      });
                      if (_canSearch) {
                        _search(_query);
                      } else {
                        setState(() => _results = []);
                      }
                    },
                    child: const Text('Azzera', style: TextStyle(color: textSecondary, fontSize: 12)),
                  ),
                ],
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
    if (!_canSearch) {
      return _buildMessage(
        Icons.restaurant_menu,
        'Cerca un alimento da aggiungere\noppure usa i filtri nutrizionali',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (_results.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _filters.hasBounds
                  ? 'Nessun alimento in catalogo con questi valori nutrizionali'
                  : 'Nessun alimento nel catalogo',
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary),
            ),
          ),
        for (final food in _results) ...[
          _tile(
            title: food.name,
            subtitle: [
              if (food.subtitle.isNotEmpty) food.subtitle,
              '${food.kcal.round()} kcal',
              'P ${food.proteinG.round()} · C ${food.carbsG.round()} · G ${food.fatG.round()} g',
            ].join(' · '),
            trailing: food.isVerified
                ? const Icon(Icons.verified_outlined, color: primaryTeal, size: 18)
                : const Icon(Icons.chevron_right, color: textSecondary),
            onTap: () => _open(food),
          ),
          const SizedBox(height: 8),
        ],
        if (!_loading) ..._buildOffSection(),
        if (!_loading)
          TextButton.icon(
            onPressed: _createPersonalFood,
            icon: const Icon(Icons.edit_note, color: textSecondary),
            label: const Text('Crea un alimento personale', style: TextStyle(color: textSecondary)),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Risultati del database esteso, mostrati come semplici "altri prodotti":
  /// all'utente non interessa da quale fonte arrivano.
  List<Widget> _buildOffSection() {
    if (_offLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryTeal))),
        ),
      ];
    }
    if (_offResults == null) {
      return [
        if (_offError != null) ...[
          Text(_offError!, textAlign: TextAlign.center, style: const TextStyle(color: textSecondary)),
          TextButton(onPressed: _searchOff, child: const Text('Riprova', style: TextStyle(color: primaryTeal))),
        ] else if (_query.length >= 3)
          TextButton.icon(
            onPressed: _searchOff,
            icon: const Icon(Icons.manage_search, color: primaryTeal),
            label: const Text('Mostra altri prodotti', style: TextStyle(color: primaryTeal)),
          ),
      ];
    }
    if (_offResults!.isEmpty) return const [];
    return [
      const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 8),
        child: Text('Altri prodotti', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
      ),
      for (final p in _offResults!) ...[
        _tile(
          title: p.name,
          subtitle: [
            if (p.brandLabel != null) p.brandLabel!,
            '${p.kcal.round()} kcal',
            'P ${p.proteinG.round()} · C ${p.carbsG.round()} · G ${p.fatG.round()} g',
          ].join(' · '),
          trailing: _importingBarcode == p.barcode
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primaryTeal))
              : const Icon(Icons.chevron_right, color: textSecondary),
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
