import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/community_models.dart';
import '../../core/models.dart';
import '../../core/recipe_service.dart';
import 'recipe_detail_screen.dart';
import 'recipe_editor_screen.dart';

/// Scelta di una ricetta da aggiungere al diario per un pasto.
/// Restituisce `true` se qualcosa è stato registrato.
class RecipesPickerScreen extends StatefulWidget {
  const RecipesPickerScreen({super.key, required this.slot, required this.date});

  final MealSlot slot;
  final DateTime date;

  @override
  State<RecipesPickerScreen> createState() => _RecipesPickerScreenState();
}

class _RecipesPickerScreenState extends State<RecipesPickerScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color colorP = Color(0xFF5A44F2);
  static const Color colorC = Color(0xFFF0A500);
  static const Color colorG = Color(0xFFEB5A0C);

  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Recipe> _recipes = [];
  bool _loading = true;
  String? _error;
  final Set<String> _restrictions = {};
  bool _onlySlot = true;
  // 0 = dal mio nutrizionista, 1 = tutte
  int _section = 0;
  bool _sectionChosen = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recipes = await RecipeService.getRecipesForMe(
        slot: _onlySlot ? widget.slot : null,
        restrictions: _restrictions.toList(),
        query: _searchController.text,
      );
      if (!mounted || request != _requestId) return;
      setState(() {
        _recipes = recipes;
        _loading = false;
        // Senza ricette del nutrizionista si parte da "Tutte"
        if (!_sectionChosen) _section = recipes.any((r) => r.fromMyNutritionist) ? 0 : 1;
      });
    } on AppError catch (e) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _load);
  }

  Future<void> _openRecipe(Recipe recipe) async {
    final logged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: recipe.id, initialSlot: widget.slot, date: widget.date),
      ),
    );
    if (!mounted) return;
    if (logged == true) Navigator.pop(context, true);
  }

  Future<void> _createRecipe() async {
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const RecipeEditorScreen()));
  }

  List<Recipe> get _visible =>
      _section == 0 ? _recipes.where((r) => r.fromMyNutritionist).toList() : _recipes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Ricette · ${widget.slot.label}',
            style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Crea la tua ricetta',
            icon: const Icon(Icons.add, color: textPrimary),
            onPressed: _createRecipe,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cerca una ricetta',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FilterChip(
                  label: Text('Solo per ${widget.slot.label}'),
                  selected: _onlySlot,
                  selectedColor: primaryTeal.withValues(alpha: 0.15),
                  checkmarkColor: primaryTeal,
                  onSelected: (v) {
                    setState(() => _onlySlot = v);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                for (final entry in dietaryRestrictionLabels.entries) ...[
                  FilterChip(
                    label: Text(entry.value),
                    selected: _restrictions.contains(entry.key),
                    selectedColor: primaryTeal.withValues(alpha: 0.15),
                    checkmarkColor: primaryTeal,
                    onSelected: (v) {
                      setState(() => v ? _restrictions.add(entry.key) : _restrictions.remove(entry.key));
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Dal tuo nutrizionista')),
                  ButtonSegment(value: 1, label: Text('Tutte le ricette')),
                ],
                selected: {_section},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _section = s.first;
                  _sectionChosen = true;
                }),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: primaryTeal));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: textSecondary)),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: primaryTeal),
                onPressed: _load,
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }
    final recipes = _visible;
    if (recipes.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      color: primaryTeal,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: recipes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildCard(recipes[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    final filtered = _searchController.text.trim().isNotEmpty || _restrictions.isNotEmpty;
    final text = filtered
        ? 'Nessuna ricetta corrisponde ai filtri scelti.'
        : _section == 0
            ? 'Qui compariranno le ricette che il tuo nutrizionista pubblica per te.'
            : 'Non ci sono ancora ricette per questo pasto. Le ricette del tuo nutrizionista compariranno qui.';
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Icon(Icons.restaurant_menu, size: 56, color: textSecondary),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: textSecondary, fontSize: 15)),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: primaryTeal),
            onPressed: _createRecipe,
            icon: const Icon(Icons.add),
            label: const Text('Crea la tua ricetta'),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Recipe r) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openRecipe(r),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(r.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary)),
                ),
                if (r.socialUrl != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.play_circle_outline, size: 20, color: textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(r.authorName ?? 'Autore sconosciuto',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(color: textSecondary, fontSize: 13)),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 14, color: primaryTeal),
                const SizedBox(width: 2),
                const Text('Verificata',
                    style: TextStyle(color: primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
                if (r.prepMinutes != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.schedule, size: 14, color: textSecondary),
                  const SizedBox(width: 2),
                  Text('${r.prepMinutes} min', style: const TextStyle(color: textSecondary, fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${r.kcalPerServing.round()} kcal',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                const Text(' / porzione', style: TextStyle(color: textSecondary, fontSize: 12)),
                const Spacer(),
                _macro('P', r.proteinPerServing, colorP),
                const SizedBox(width: 10),
                _macro('C', r.carbsPerServing, colorC),
                const SizedBox(width: 10),
                _macro('G', r.fatPerServing, colorG),
              ],
            ),
            if (r.restrictionTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in r.restrictionTags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(dietaryRestrictionLabels[t] ?? t,
                          style: const TextStyle(color: primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _macro(String label, double value, Color color) => Text(
        '$label ${value.round()}g',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
      );
}
