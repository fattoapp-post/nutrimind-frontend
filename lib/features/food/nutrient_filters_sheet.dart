import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/models.dart';

/// Filtri sui valori nutrizionali per 100 g: "almeno 50 g di proteine e
/// meno di 10 g di grassi". Restituisce i filtri scelti, o
/// [NutrientFilters.none] se l'utente li azzera.
class NutrientFiltersSheet extends StatefulWidget {
  final NutrientFilters initial;

  const NutrientFiltersSheet({super.key, required this.initial});

  static Future<NutrientFilters?> show(BuildContext context, NutrientFilters initial) {
    return showModalBottomSheet<NutrientFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF17221F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => NutrientFiltersSheet(initial: initial),
    );
  }

  @override
  State<NutrientFiltersSheet> createState() => _NutrientFiltersSheetState();
}

class _NutrientFiltersSheetState extends State<NutrientFiltersSheet> {

  late final _minProtein = _ctrl(widget.initial.minProtein);
  late final _maxProtein = _ctrl(widget.initial.maxProtein);
  late final _minCarbs = _ctrl(widget.initial.minCarbs);
  late final _maxCarbs = _ctrl(widget.initial.maxCarbs);
  late final _minFat = _ctrl(widget.initial.minFat);
  late final _maxFat = _ctrl(widget.initial.maxFat);
  late final _minKcal = _ctrl(widget.initial.minKcal);
  late final _maxKcal = _ctrl(widget.initial.maxKcal);
  late String? _sort = widget.initial.sort;

  String? _error;

  List<TextEditingController> get _all =>
      [_minProtein, _maxProtein, _minCarbs, _maxCarbs, _minFat, _maxFat, _minKcal, _maxKcal];

  TextEditingController _ctrl(double? v) => TextEditingController(text: v == null ? '' : _fmt(v));

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  /// Valore del campo; lancia [FormatException] se non è un numero valido.
  double? _value(TextEditingController c, {double max = 10000}) {
    final s = c.text.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null || v < 0 || v > max) throw const FormatException('valore non valido');
    return v;
  }

  void _apply() {
    try {
      final filters = NutrientFilters(
        minProtein: _value(_minProtein, max: 100),
        maxProtein: _value(_maxProtein, max: 100),
        minCarbs: _value(_minCarbs, max: 100),
        maxCarbs: _value(_maxCarbs, max: 100),
        minFat: _value(_minFat, max: 100),
        maxFat: _value(_maxFat, max: 100),
        minKcal: _value(_minKcal),
        maxKcal: _value(_maxKcal),
        sort: _sort,
      );
      // Un intervallo rovesciato non restituirebbe nulla
      final inverted = [
        (filters.minProtein, filters.maxProtein),
        (filters.minCarbs, filters.maxCarbs),
        (filters.minFat, filters.maxFat),
        (filters.minKcal, filters.maxKcal),
      ].any((p) => p.$1 != null && p.$2 != null && p.$1! > p.$2!);
      if (inverted) {
        setState(() => _error = 'Il valore minimo non può superare il massimo.');
        return;
      }
      Navigator.pop(context, filters);
    } on FormatException {
      setState(() => _error = 'Usa solo numeri: i macro fino a 100 g per 100 g di prodotto.');
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text('Filtri nutrizionali',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: Icon(Icons.close, color: textSecondary), onPressed: () => Navigator.pop(context)),
              ],
            ),
            Text('Valori per 100 g di prodotto', style: TextStyle(color: textSecondary)),
            const SizedBox(height: 16),
            _row('Proteine', colorP, _minProtein, _maxProtein, 'g'),
            _row('Carboidrati', colorC, _minCarbs, _maxCarbs, 'g'),
            _row('Grassi', colorG, _minFat, _maxFat, 'g'),
            _row('Calorie', textSecondary, _minKcal, _maxKcal, 'kcal'),
            const SizedBox(height: 8),
            Text('Ordina per', style: TextStyle(color: textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in NutrientFilters.sortLabels.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _sort == e.key,
                    backgroundColor: bgColor,
                    selectedColor: primaryTeal,
                    labelStyle: TextStyle(color: _sort == e.key ? Colors.white : textSecondary),
                    side: BorderSide(color: _sort == e.key ? primaryTeal : borderColor),
                    onSelected: (on) => setState(() => _sort = on ? e.key : null),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, NutrientFilters.none),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: borderColor),
                    ),
                    child: Text('Azzera', style: TextStyle(color: textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Applica'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, Color color, TextEditingController min, TextEditingController max, String unit) {
    InputDecoration dec(String hint) => InputDecoration(
          labelText: hint,
          labelStyle: TextStyle(color: textSecondary, fontSize: 13),
          suffixText: unit,
          suffixStyle: TextStyle(color: textSecondary, fontSize: 12),
          isDense: true,
          filled: true,
          fillColor: bgColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryTeal),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: min,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: dec('Almeno'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: max,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: dec('Al massimo'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
