import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/nutritionist_service.dart';

/// Nuovo alimento nel catalogo (solo nutrizionisti verificati), con una
/// porzione opzionale. Valori nutrizionali per 100 g.
class CreateFoodScreen extends StatefulWidget {
  const CreateFoodScreen({super.key});

  @override
  State<CreateFoodScreen> createState() => _CreateFoodScreenState();
}

class _CreateFoodScreenState extends State<CreateFoodScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _barcode = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _portionLabel = TextEditingController();
  final _portionGrams = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _brand, _barcode, _kcal, _protein, _carbs, _fat, _portionLabel, _portionGrams]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  String? _requiredNumber(String? v) {
    final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (n == null || n < 0) return 'Valore non valido';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final p = _num(_protein)!, c = _num(_carbs)!, f = _num(_fat)!;
    // Vincolo foods_macro_sum_plausible del DB
    if (p + c + f > 100.5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proteine + carboidrati + grassi non possono superare 100 g.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final foodId = await NutritionistService.createFood(
        name: _name.text.trim(),
        kcal: _num(_kcal)!,
        proteinG: p,
        carbsG: c,
        fatG: f,
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      );
      final grams = _num(_portionGrams);
      if (_portionLabel.text.trim().isNotEmpty && grams != null && grams > 0) {
        await NutritionistService.createFoodPortion(foodId, _portionLabel.text.trim(), grams);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alimento creato.')));
      Navigator.pop(context, true);
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo alimento')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome *'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obbligatorio' : null,
            ),
            TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'Marca')),
            TextFormField(
              controller: _barcode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Codice a barre'),
            ),
            const SizedBox(height: 16),
            const Text('Valori per 100 g', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final (label, c) in [
              ('Calorie (kcal) *', _kcal),
              ('Proteine (g) *', _protein),
              ('Carboidrati (g) *', _carbs),
              ('Grassi (g) *', _fat),
            ])
              TextFormField(
                controller: c,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: label),
                validator: _requiredNumber,
              ),
            const SizedBox(height: 16),
            const Text('Porzione (opzionale)', style: TextStyle(fontWeight: FontWeight.bold)),
            TextFormField(controller: _portionLabel, decoration: const InputDecoration(labelText: 'Etichetta (es. 1 mela media)')),
            TextFormField(
              controller: _portionGrams,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Grammi'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Salvataggio...' : 'Crea alimento')),
          ],
        ),
      ),
    );
  }
}
