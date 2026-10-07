import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/community_models.dart';
import '../../core/food_service.dart';
import '../../core/models.dart';
import '../../core/recipe_service.dart';
import '../../core/theme.dart';

/// Foglio per consigliare a *quel* paziente una ricetta o un alimento.
///
/// Le ricette pubblicate valgono per tutti i pazienti; questo serve
/// quando si vuole indicare qualcosa di preciso a una persona, con una
/// nota che spiega il perché.
class SuggestToPatientSheet extends StatefulWidget {
  final String patientId;
  final String patientName;

  const SuggestToPatientSheet({super.key, required this.patientId, required this.patientName});

  /// Restituisce `true` se è stato aggiunto un consiglio.
  static Future<bool?> show(BuildContext context, {required String patientId, required String patientName}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SuggestToPatientSheet(patientId: patientId, patientName: patientName),
      ),
    );
  }

  @override
  State<SuggestToPatientSheet> createState() => _SuggestToPatientSheetState();
}

class _SuggestToPatientSheetState extends State<SuggestToPatientSheet> {
  final _note = TextEditingController();
  final _query = TextEditingController();
  Timer? _debounce;

  bool _recipes = true;
  List<Recipe> _myRecipes = [];
  List<Food> _foods = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _note.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await RecipeService.getMyRecipes();
      final q = _query.text.trim().toLowerCase();
      if (mounted) {
        setState(() {
          _myRecipes = q.isEmpty ? all : all.where((r) => r.title.toLowerCase().contains(q)).toList();
          _loading = false;
        });
      }
    } on AppError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _searchFoods() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() {
        _foods = [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await FoodService.searchFoods(q, limit: 20);
      if (mounted && q == _query.text.trim()) {
        setState(() {
          _foods = found;
          _loading = false;
        });
      }
    } on AppError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _recipes ? _loadRecipes() : _searchFoods());
  }

  Future<void> _suggest({String? mealId, String? foodId, required String label}) async {
    setState(() => _busyId = mealId ?? foodId);
    try {
      await SuggestionService.add(
        patientId: widget.patientId,
        mealId: mealId,
        foodId: foodId,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$label" consigliato a ${widget.patientName}.')),
      );
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Consiglia a ${widget.patientName}',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Lo vedrà nel diario, fra i consigli per lui.',
                style: TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Le mie ricette'), icon: Icon(Icons.menu_book_outlined)),
                ButtonSegment(value: false, label: Text('Alimenti'), icon: Icon(Icons.restaurant)),
              ],
              selected: {_recipes},
              onSelectionChanged: (v) {
                setState(() {
                  _recipes = v.first;
                  _loading = true;
                });
                _recipes ? _loadRecipes() : _searchFoods();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: _recipes ? 'Filtra le tue ricette' : 'Cerca un alimento',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Nota per il paziente (facoltativa)',
                hintText: 'Es. "Al posto della colazione del mercoledì"',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return Center(child: CircularProgressIndicator(color: primaryTeal));
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
          TextButton(onPressed: _recipes ? _loadRecipes : _searchFoods, child: const Text('Riprova')),
        ]),
      );
    }

    if (_recipes) {
      if (_myRecipes.isEmpty) {
        return Center(
          child: Text('Non hai ricette da consigliare.\nCreane una dalla scheda Ricette.',
              textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
        );
      }
      return ListView.builder(
        itemCount: _myRecipes.length,
        itemBuilder: (_, i) {
          final r = _myRecipes[i];
          return _tile(
            id: r.id,
            title: r.title,
            subtitle: '${r.kcalPerServing.round()} kcal a porzione · '
                'P ${r.proteinPerServing.round()} · C ${r.carbsPerServing.round()} · G ${r.fatPerServing.round()} g',
            onTap: () => _suggest(mealId: r.id, label: r.title),
          );
        },
      );
    }

    if (_query.text.trim().length < 2) {
      return Center(
        child: Text('Scrivi almeno due lettere per cercare un alimento.',
            textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
      );
    }
    if (_foods.isEmpty) {
      return Center(child: Text('Nessun alimento trovato.', style: TextStyle(color: textSecondary)));
    }
    return ListView.builder(
      itemCount: _foods.length,
      itemBuilder: (_, i) {
        final f = _foods[i];
        return _tile(
          id: f.id,
          title: f.name,
          subtitle: [
            if (f.brandLabel != null) f.brandLabel!,
            '${f.kcal.round()} kcal / 100 g',
          ].join(' · '),
          onTap: () => _suggest(foodId: f.id, label: f.name),
        );
      },
    );
  }

  Widget _tile({
    required String id,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12)),
      trailing: _busyId == id
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primaryTeal))
          : Icon(Icons.add_circle_outline, color: primaryTeal),
      onTap: _busyId == null ? onTap : null,
    );
  }
}
