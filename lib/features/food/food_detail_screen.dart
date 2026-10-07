import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/food_service.dart';
import '../../core/models.dart';

/// Dettaglio alimento. Restituisce `true` se è stato aggiunto al diario.
class FoodDetailScreen extends StatefulWidget {
  final Food food;
  final MealSlot? initialSlot;
  final DateTime? date;
  final double? initialGrams;

  const FoodDetailScreen({super.key, required this.food, this.initialSlot, this.date, this.initialGrams});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
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

  late int _currentGrams;
  bool _isFavorite = false;
  bool _savingFavorite = false;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _currentGrams = (widget.initialGrams ?? widget.food.servingG ?? 100).round().clamp(10, 5000);
    _loadFavorite();
    _loadPortions();
  }

  List<FoodPortion> _portions = [];

  Future<void> _loadPortions() async {
    try {
      final portions = await FoodService.getPortions(widget.food.id);
      if (mounted) setState(() => _portions = portions);
    } on AppError {
      // le porzioni sono un aiuto: senza, resta la quantità manuale
    }
  }

  Future<void> _loadFavorite() async {
    try {
      final fav = await FoodService.isFavorite(widget.food.id);
      if (mounted) setState(() => _isFavorite = fav);
    } on AppError {
      // stato preferito non disponibile: resta "Salva"
    }
  }

  Future<void> _toggleFavorite() async {
    final target = !_isFavorite;
    setState(() {
      _isFavorite = target;
      _savingFavorite = true;
    });
    try {
      await FoodService.setFavorite(widget.food.id, target, defaultGrams: _currentGrams.toDouble());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(target ? '${widget.food.name} salvato nei preferiti!' : 'Rimosso dai preferiti.'),
          backgroundColor: target ? primaryTeal : Colors.grey,
        ),
      );
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _isFavorite = !target);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final bool isVerified = food.isVerified;

    // I valori in catalogo sono per 100 g
    double ratio = _currentGrams / 100.0;
    int calcKcal = (food.kcal * ratio).round();
    int calcP = (food.proteinG * ratio).round();
    int calcC = (food.carbsG * ratio).round();
    int calcG = (food.fatG * ratio).round();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Dettaglio alimento', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.more_horiz, color: textPrimary), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary)),
                      if (food.subtitle.isNotEmpty)
                        Text(food.subtitle, style: const TextStyle(fontSize: 16, color: textSecondary)),
                    ],
                  ),
                ),
                _buildVerificationBadge(isVerified),
              ],
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(child: _buildBigMacroCard('Proteine', 'P', calcP, colorP, bgP)),
                const SizedBox(width: 12),
                Expanded(child: _buildBigMacroCard('Carboidrati', 'C', calcC, colorC, bgC)),
                const SizedBox(width: 12),
                Expanded(child: _buildBigMacroCard('Grassi', 'G', calcG, colorG, bgG)),
              ],
            ),
            const SizedBox(height: 16),
            Center(child: Text('$calcKcal kcal · dato ricalcolato', style: const TextStyle(color: textSecondary))),
            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Quantità', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                      Text('Personalizzata', style: TextStyle(color: textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQtyButton(Icons.remove, () {
                        if (_currentGrams > 10) setState(() => _currentGrams -= 10);
                      }),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: '$_currentGrams', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary)),
                            const TextSpan(text: ' g', style: TextStyle(fontSize: 18, color: textSecondary)),
                          ],
                        ),
                      ),
                      _buildQtyButton(Icons.add, () {
                        setState(() => _currentGrams += 10);
                      }, isFilled: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.sync, color: primaryTeal, size: 16),
                      SizedBox(width: 8),
                      Text('Macro ricalcolati in tempo reale', style: TextStyle(color: primaryTeal, fontSize: 12)),
                    ],
                  ),
                  if (_portions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in _portions)
                          ChoiceChip(
                            label: Text('${p.label} · ${p.grams.round()} g'),
                            selected: _currentGrams == p.grams.round(),
                            selectedColor: const Color(0xFFE6F4F1),
                            onSelected: (_) => setState(() => _currentGrams = p.grams.round()),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF3F9F8), borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(isVerified ? Icons.verified_user_outlined : Icons.info_outline, color: primaryTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isVerified
                          ? 'Valori verificati sul prodotto. Controlla sempre la confezione in caso di variazioni.'
                          : food.isUserCreated
                              ? 'Alimento personale inserito da te: non è ancora stato revisionato.'
                              : 'Valori non ancora verificati. Controlla la confezione prima di registrare.',
                      style: const TextStyle(color: textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildNutritionTable(food),
            if (food.nutriscoreGrade != null || food.novaGroup != null) ...[
              const SizedBox(height: 16),
              _buildScores(food),
            ],
            if (food.ingredientsText != null || food.allergensText != null || food.tracesText != null) ...[
              const SizedBox(height: 16),
              _buildIngredients(food),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
      
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Tasto dinamico: Salva / Salvato
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _savingFavorite ? null : _toggleFavorite,
                  icon: Icon(
                    _isFavorite ? Icons.bookmark : Icons.bookmark_border, 
                    color: _isFavorite ? Colors.white : primaryTeal
                  ),
                  label: Text(
                    _isFavorite ? 'Salvato' : 'Salva', 
                    style: TextStyle(color: _isFavorite ? Colors.white : primaryTeal, fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFavorite ? primaryTeal : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: primaryTeal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _adding ? null : () => _showMealSelectionSheet(context, food),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(_adding ? 'Attendi...' : 'Aggiungi', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Valori per 100 g e per la quantità selezionata.
  Widget _buildNutritionTable(Food food) {
    final ratio = _currentGrams / 100.0;
    String fmt(double? v, {int decimals = 1}) => v == null ? '—' : v.toStringAsFixed(decimals);
    final rows = <(String, double?, String, bool)>[
      ('Energia', food.kcal, 'kcal', false),
      ('Proteine', food.proteinG, 'g', false),
      ('Carboidrati', food.carbsG, 'g', false),
      ('di cui zuccheri', food.sugarsG, 'g', true),
      ('Grassi', food.fatG, 'g', false),
      ('di cui saturi', food.saturatedFatG, 'g', true),
      ('Fibre', food.fiberG, 'g', false),
      ('Sale', food.saltG, 'g', false),
    ];
    const header = TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Valori nutrizionali', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
          if (food.quantityText != null)
            Text('Confezione: ${food.quantityText}', style: const TextStyle(color: textSecondary)),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
            children: [
              TableRow(children: [
                const SizedBox.shrink(),
                const Text('100 g', textAlign: TextAlign.right, style: header),
                Text('$_currentGrams g', textAlign: TextAlign.right, style: header),
              ]),
              for (final (label, value, unit, indent) in rows)
                TableRow(children: [
                  Padding(
                    padding: EdgeInsets.only(top: 8, left: indent ? 12 : 0),
                    child: Text(label, style: TextStyle(color: indent ? textSecondary : textPrimary)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${fmt(value, decimals: unit == 'kcal' ? 0 : 1)} $unit', textAlign: TextAlign.right),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${fmt(value == null ? null : value * ratio, decimals: unit == 'kcal' ? 0 : 1)} $unit',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScores(Food food) {
    const nutriColors = {
      'A': Color(0xFF038141),
      'B': Color(0xFF85BB2F),
      'C': Color(0xFFFECB02),
      'D': Color(0xFFEE8100),
      'E': Color(0xFFE63E11),
    };
    const novaLabels = {
      1: 'Non trasformato',
      2: 'Ingredienti culinari',
      3: 'Trasformato',
      4: 'Ultra-trasformato',
    };
    Widget badge(String title, String value, Color color, String caption) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                  Text(caption, style: const TextStyle(color: textSecondary, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        );
    final grade = food.nutriscoreGrade;
    final nova = food.novaGroup;
    return Row(children: [
      if (grade != null && nutriColors.containsKey(grade))
        badge('Nutri-Score', grade, nutriColors[grade]!, 'Qualità nutrizionale'),
      if (grade != null && nova != null) const SizedBox(width: 12),
      if (nova != null && novaLabels.containsKey(nova))
        badge('NOVA', '$nova', nova >= 4 ? const Color(0xFFE63E11) : (nova == 3 ? const Color(0xFFEE8100) : primaryTeal), novaLabels[nova]!),
    ]);
  }

  Widget _buildIngredients(Food food) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (food.allergensText != null || food.tracesText != null) ...[
            const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEE8100), size: 20),
              SizedBox(width: 6),
              Text('Allergeni', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
            ]),
            const SizedBox(height: 6),
            if (food.allergensText != null) Text(_cleanTags(food.allergensText!)),
            if (food.tracesText != null)
              Text('Può contenere tracce di: ${_cleanTags(food.tracesText!)}', style: const TextStyle(color: textSecondary)),
            const SizedBox(height: 12),
          ],
          if (food.ingredientsText != null) ...[
            const Text('Ingredienti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 6),
            Text(food.ingredientsText!, style: const TextStyle(color: textPrimary, height: 1.4)),
          ],
        ],
      ),
    );
  }

  /// "en:milk,en:nuts" (tag Open Food Facts) -> "milk, nuts"
  static String _cleanTags(String raw) => raw
      .split(',')
      .map((t) => t.trim().replaceFirst(RegExp(r'^[a-z]{2}:'), '').replaceAll('-', ' '))
      .where((t) => t.isNotEmpty)
      .join(', ');

  Widget _buildBigMacroCard(String name, String letter, int amount, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: textColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(letter, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$amount', style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
                TextSpan(text: 'g', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap, {bool isFilled = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isFilled ? primaryTeal : Colors.transparent,
          border: isFilled ? null : Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: isFilled ? Colors.white : textPrimary),
      ),
    );
  }

  Widget _buildVerificationBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: isVerified ? const Color(0xFFE6F4F1) : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(isVerified ? Icons.verified_outlined : Icons.info_outline, size: 14, color: isVerified ? primaryTeal : textSecondary),
          const SizedBox(width: 6),
          Text(isVerified ? 'Verificato' : 'Non verificato', style: TextStyle(color: isVerified ? primaryTeal : textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _addToDiary(MealSlot slot) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = true);
    try {
      await FoodService.logMeal(
        food: widget.food,
        slot: slot,
        grams: _currentGrams.toDouble(),
        date: widget.date ?? DateTime.now(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text('Aggiunto a ${slot.label}!'), backgroundColor: Colors.green),
      );
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _adding = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _showMealSelectionSheet(BuildContext context, Food food) {
    final initial = widget.initialSlot ?? MealSlot.forNow();

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Aggiungi al diario', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...MealSlot.values.map((slot) => ListTile(
                title: Text(
                  slot.label,
                  style: TextStyle(color: textPrimary, fontWeight: slot == initial ? FontWeight.bold : FontWeight.normal),
                ),
                trailing: Icon(slot == initial ? Icons.add_circle : Icons.add_circle_outline, color: primaryTeal),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _addToDiary(slot);
                },
              )),
            ],
          ),
        );
      },
    );
  }
}