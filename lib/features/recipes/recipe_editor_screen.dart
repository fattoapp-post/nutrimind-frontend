import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'package:flutter/services.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/community_models.dart';
import '../../core/food_service.dart';
import '../../core/links.dart';
import '../../core/models.dart';
import '../../core/recipe_service.dart';

/// Creazione o modifica di una bozza di ricetta. Restituisce `true` se salvata.
class RecipeEditorScreen extends StatefulWidget {
  const RecipeEditorScreen({super.key, this.recipeId});

  final String? recipeId;

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

/// Ingrediente in modifica: alimento + grammi (testo libero finché non si salva).
class _EditableIngredient {
  _EditableIngredient(this.food, double grams) : grams = TextEditingController(text: _fmt(grams));

  final Food food;
  final TextEditingController grams;

  double? get parsedGrams => double.tryParse(grams.text.trim().replaceAll(',', '.'));

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {


  final _title = TextEditingController();
  final _description = TextEditingController();
  final _instructions = TextEditingController();
  final _prepMinutes = TextEditingController();
  final _socialUrl = TextEditingController();

  int _servings = 1;
  final Set<MealSlot> _slots = {};
  final Set<String> _restrictions = {};
  final Set<String> _goals = {};
  String _visibility = 'public';
  final List<_EditableIngredient> _ingredients = [];

  bool _isNutritionist = false;
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  String? _titleError;
  String? _socialError;

  bool get _isNew => widget.recipeId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _instructions.dispose();
    _prepMinutes.dispose();
    _socialUrl.dispose();
    for (final i in _ingredients) {
      i.grams.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final id = widget.recipeId;
      final recipe = id == null ? null : await RecipeService.getRecipe(id);
      bool isNutritionist = false;
      try {
        isNutritionist = (await AccountService.getProfile()).isNutritionist;
      } on AppError {
        // senza profilo si usa il flusso da paziente
      }
      if (!mounted) return;
      setState(() {
        _isNutritionist = isNutritionist;
        if (isNutritionist && recipe == null) _visibility = 'patients';
        if (recipe != null) _prefill(recipe);
        _loading = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  void _prefill(Recipe r) {
    _title.text = r.title;
    _description.text = r.description ?? '';
    _instructions.text = r.instructions ?? '';
    _prepMinutes.text = r.prepMinutes?.toString() ?? '';
    _socialUrl.text = r.socialUrl ?? '';
    _servings = r.servings.clamp(1, 12);
    _slots
      ..clear()
      ..addAll(r.slots);
    _restrictions
      ..clear()
      ..addAll(r.restrictionTags);
    _goals
      ..clear()
      ..addAll(r.goalTags);
    _visibility = r.visibility;
    for (final i in _ingredients) {
      i.grams.dispose();
    }
    _ingredients
      ..clear()
      ..addAll(r.ingredients.map((i) => _EditableIngredient(i.food, i.grams)));
  }

  ({double kcal, double p, double c, double g}) get _perServing {
    double kcal = 0, p = 0, c = 0, g = 0;
    for (final i in _ingredients) {
      final grams = i.parsedGrams ?? 0;
      kcal += i.food.kcal * grams / 100;
      p += i.food.proteinG * grams / 100;
      c += i.food.carbsG * grams / 100;
      g += i.food.fatG * grams / 100;
    }
    return (kcal: kcal / _servings, p: p / _servings, c: c / _servings, g: g / _servings);
  }

  Future<void> _addIngredient() async {
    final picked = await showModalBottomSheet<({Food food, double grams})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _FoodPickerSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() => _ingredients.add(_EditableIngredient(picked.food, picked.grams)));
  }

  void _removeIngredient(int index) {
    final removed = _ingredients.removeAt(index);
    setState(() {});
    // il controller può essere ancora usato nel frame corrente
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.grams.dispose());
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    final title = _title.text.trim();
    String? socialUrl;
    String? socialError;
    try {
      socialUrl = normalizeHttpsUrl(_socialUrl.text);
    } on FormatException {
      socialError = 'Inserisci un link valido (https://…)';
    }
    setState(() {
      _titleError = title.length < 3 ? 'Il titolo deve avere almeno 3 caratteri' : null;
      _socialError = socialError;
    });
    if (title.length < 3 || socialError != null) return;
    if (_ingredients.isEmpty) {
      _snack('Aggiungi almeno un ingrediente.');
      return;
    }
    final ingredients = <({String foodId, double grams})>[];
    for (final i in _ingredients) {
      final grams = i.parsedGrams;
      if (grams == null || grams <= 0 || grams > 5000) {
        _snack('Controlla i grammi di ${i.food.name}.');
        return;
      }
      ingredients.add((foodId: i.food.id, grams: grams));
    }
    final prepText = _prepMinutes.text.trim();
    final prep = prepText.isEmpty ? null : int.tryParse(prepText);
    if (prepText.isNotEmpty && (prep == null || prep > 1440)) {
      _snack('Il tempo di preparazione deve essere tra 0 e 1440 minuti.');
      return;
    }

    setState(() => _saving = true);
    try {
      final description = _description.text.trim();
      final instructions = _instructions.text.trim();
      await RecipeService.saveDraft(
        id: widget.recipeId,
        title: title,
        description: description.isEmpty ? null : description,
        instructions: instructions.isEmpty ? null : instructions,
        slots: MealSlot.values.where(_slots.contains).toList(),
        servings: _servings,
        restrictionTags: _restrictions.toList(),
        goalTags: _goals.toList(),
        socialUrl: socialUrl,
        prepMinutes: prep,
        visibility: _visibility,
        ingredients: ingredients,
      );
      if (!mounted) return;
      _snack('Bozza salvata');
      Navigator.pop(context, true);
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isNew ? 'Nuova ricetta' : 'Modifica ricetta',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (!_loading && _loadError == null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text('Salva', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return Center(child: CircularProgressIndicator(color: primaryTeal));
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _infoCard(),
        const SizedBox(height: 16),
        _card(
          child: Column(
            children: [
              TextField(
                controller: _title,
                maxLength: 100, // limite del vincolo suggested_meals_title_check
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (_titleError != null) setState(() => _titleError = null);
                },
                decoration: _decoration('Titolo *', errorText: _titleError),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLength: 300,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration('Descrizione breve'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _instructions,
                minLines: 4,
                maxLines: 12,
                // limite della colonna instructions (8000)
                inputFormatters: [LengthLimitingTextInputFormatter(8000)],
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration('Procedimento', alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prepMinutes,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: _decoration('Tempo (minuti)'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Porzioni', style: TextStyle(color: textSecondary)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                  ),
                  Text('$_servings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _servings < 12 ? () => setState(() => _servings++) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Ingredienti'),
        const SizedBox(height: 8),
        _buildIngredients(),
        const SizedBox(height: 20),
        _sectionTitle('Pasti adatti'),
        const SizedBox(height: 8),
        _chips<MealSlot>(MealSlot.values, (s) => s.label, _slots),
        const SizedBox(height: 20),
        _sectionTitle('Restrizioni'),
        const SizedBox(height: 8),
        _chips<String>(dietaryRestrictionLabels.keys, (k) => dietaryRestrictionLabels[k]!, _restrictions),
        const SizedBox(height: 20),
        _sectionTitle('Obiettivi'),
        const SizedBox(height: 8),
        _chips<String>(goalTagLabels.keys, (k) => goalTagLabels[k]!, _goals),
        const SizedBox(height: 20),
        _sectionTitle('Link social'),
        const SizedBox(height: 8),
        TextField(
          controller: _socialUrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (_) {
            if (_socialError != null) setState(() => _socialError = null);
          },
          decoration: _decoration('Video o post della ricetta (facoltativo)',
              hintText: 'https://www.instagram.com/p/…', errorText: _socialError),
        ),
        if (_isNutritionist) ...[
          const SizedBox(height: 20),
          _sectionTitle('Visibilità'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'public', label: Text('Tutti'), icon: Icon(Icons.public)),
                ButtonSegment(value: 'patients', label: Text('Solo i miei pazienti'), icon: Icon(Icons.people_outline)),
              ],
              selected: {_visibility},
              onSelectionChanged: (s) => setState(() => _visibility = s.first),
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primaryTeal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Salva bozza', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _infoCard() {
    final text = _isNutritionist
        ? 'Salva la bozza e pubblicala dalla scheda della ricetta.'
        : 'Dopo il salvataggio inviala al tuo nutrizionista: diventerà visibile dopo la sua verifica.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryTeal.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: primaryTeal, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: textPrimary, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildIngredients() {
    final totals = _perServing;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_ingredients.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Nessun ingrediente. Aggiungi almeno un alimento.',
                  style: TextStyle(color: textSecondary)),
            ),
          for (var i = 0; i < _ingredients.length; i++) ...[
            if (i > 0) Divider(height: 16, color: borderColor),
            Row(
              key: ObjectKey(_ingredients[i]),
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_ingredients[i].food.name,
                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                      if (_ingredients[i].food.brandLabel != null)
                        Text(_ingredients[i].food.brandLabel!,
                            style: TextStyle(color: textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _ingredients[i].grams,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    textAlign: TextAlign.end,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(isDense: true, suffixText: 'g'),
                  ),
                ),
                IconButton(
                  tooltip: 'Rimuovi',
                  icon: Icon(Icons.delete_outline, color: textSecondary),
                  onPressed: () => _removeIngredient(i),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: primaryTeal),
            onPressed: _addIngredient,
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi ingrediente'),
          ),
          if (_ingredients.isNotEmpty) ...[
            Divider(height: 20, color: borderColor),
            Text('Per porzione: ${totals.kcal.round()} kcal',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                _macro('P', totals.p, colorP),
                const SizedBox(width: 12),
                _macro('C', totals.c, colorC),
                const SizedBox(width: 12),
                _macro('G', totals.g, colorG),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chips<T>(Iterable<T> values, String Function(T) label, Set<T> selected) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            FilterChip(
              label: Text(label(v)),
              selected: selected.contains(v),
              selectedColor: primaryTeal.withValues(alpha: 0.15),
              checkmarkColor: primaryTeal,
              backgroundColor: cardColor,
              onSelected: (on) => setState(() => on ? selected.add(v) : selected.remove(v)),
            ),
        ],
      );

  Widget _macro(String label, double value, Color color) =>
      Text('$label ${value.round()}g', style: TextStyle(color: color, fontWeight: FontWeight.w600));

  InputDecoration _decoration(String label, {String? hintText, String? errorText, bool alignLabelWithHint = false}) =>
      InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        alignLabelWithHint: alignLabelWithHint,
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
      );

  Widget _sectionTitle(String text) =>
      Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary));

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: child,
      );
}

/// Ricerca di un alimento nel catalogo e scelta dei grammi.
class _FoodPickerSheet extends StatefulWidget {
  const _FoodPickerSheet();

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {

  final _query = TextEditingController();
  final _grams = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  List<Food> _results = [];
  bool _searching = false;
  String? _error;
  Food? _selected;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _grams.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      _requestId++;
      setState(() {
        _results = [];
        _searching = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    final request = ++_requestId;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final foods = await FoodService.searchFoods(query);
      if (!mounted || request != _requestId) return;
      setState(() {
        _results = foods;
        _searching = false;
      });
    } on AppError catch (e) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _error = e.message;
        _searching = false;
      });
    }
  }

  void _select(Food food) {
    final g = food.servingG ?? 100;
    _grams.text = g == g.roundToDouble() ? g.toInt().toString() : g.toStringAsFixed(1);
    setState(() => _selected = food);
  }

  void _confirm() {
    final grams = double.tryParse(_grams.text.trim().replaceAll(',', '.'));
    if (grams == null || grams <= 0 || grams > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci i grammi (1-5000).')));
      return;
    }
    Navigator.pop(context, (food: _selected!, grams: grams));
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    final height = MediaQuery.sizeOf(context).height * 0.85;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: _selected == null ? _buildSearch() : _buildGrams(_selected!),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aggiungi ingrediente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(height: 12),
        TextField(
          controller: _query,
          autofocus: true,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Cerca un alimento (min. 2 lettere)',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 8),
        if (_searching) LinearProgressIndicator(color: primaryTeal),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
            TextButton(
              onPressed: () => _search(_query.text.trim()),
              child: Text('Riprova', style: TextStyle(color: primaryTeal)),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      final text = _query.text.trim().length < 2
          ? 'Scrivi il nome di un alimento.'
          : _searching
              ? ''
              : 'Nessun alimento trovato.';
      return Center(child: Text(text, style: TextStyle(color: textSecondary)));
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: borderColor),
      itemBuilder: (_, i) {
        final f = _results[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Text(
            [if (f.brandLabel != null) f.brandLabel!, '${f.kcal.round()} kcal / 100 g'].join(' · '),
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          trailing: Icon(Icons.add_circle_outline, color: primaryTeal),
          onTap: () => _select(f),
        );
      },
    );
  }

  Widget _buildGrams(Food food) {
    final grams = double.tryParse(_grams.text.trim().replaceAll(',', '.')) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textPrimary),
              onPressed: () => setState(() => _selected = null),
            ),
            Expanded(
              child: Text('Quantità', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(food.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary)),
        if (food.brandLabel != null) Text(food.brandLabel!, style: TextStyle(color: textSecondary)),
        const SizedBox(height: 16),
        TextField(
          controller: _grams,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _confirm(),
          decoration: InputDecoration(
            labelText: 'Grammi',
            suffixText: 'g',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 8),
        Text('${(food.kcal * grams / 100).round()} kcal',
            style: TextStyle(color: textSecondary)),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primaryTeal,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _confirm,
            child: const Text('Aggiungi'),
          ),
        ),
      ],
    );
  }
}
