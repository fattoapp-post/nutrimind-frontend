import 'package:flutter/material.dart';

import '../../core/admin_service.dart';
import '../../core/app_error.dart';
import '../../core/theme.dart';
import '../profile/profile_widgets.dart';

/// Coda degli alimenti creati dalle persone e mai verificati.
///
/// `review_food` esisteva dalla prima migration e nessuna schermata la
/// chiamava: tutto ciò che scrivevano pazienti e professionisti restava
/// `unverified`, con affidabilità 1, e il catalogo non migliorava mai.
///
/// Per aiutare chi decide senza avere la confezione in mano, ogni riga
/// segnala da sé le due incoerenze più comuni: macro che sommano a più
/// di 100 g su 100 g, e calorie che non tornano con i macro.
class FoodsToReviewScreen extends StatefulWidget {
  const FoodsToReviewScreen({super.key});

  @override
  State<FoodsToReviewScreen> createState() => _FoodsToReviewScreenState();
}

class _FoodsToReviewScreenState extends State<FoodsToReviewScreen> {
  List<FoodToReview> _foods = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final foods = await AdminService.getFoodsToReview();
      if (!mounted) return;
      setState(() {
        _foods = foods;
        _loading = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _review(FoodToReview f, bool approve) async {
    setState(() => _busyId = f.id);
    try {
      await AdminService.reviewFood(f.id, approve: approve);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? '"${f.name}" verificato.' : '"${f.name}" rifiutato.')),
      );
      _load();
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return SettingsPage(
      title: 'Alimenti da verificare',
      busy: _loading,
      children: [
        if (_error != null)
          SectionCard(
            title: 'Coda non disponibile',
            subtitle: _error,
            children: [TextButton(onPressed: _load, child: const Text('Riprova'))],
          )
        else if (_foods.isEmpty && !_loading)
          SectionCard(
            title: 'Niente da verificare',
            subtitle: 'Qui arrivano gli alimenti creati da pazienti e professionisti. '
                'I prodotti importati dal catalogo esterno non passano da qui: sono troppi '
                'e la loro fonte è già tracciata.',
            children: const [],
          )
        else ...[
          SectionCard(
            title: '${_foods.length} in attesa',
            subtitle: 'Verificare un alimento alza la sua affidabilità e lo rende usabile '
                'nelle ricette dei professionisti. Rifiutarlo lo toglie dalle ricerche.',
            children: const [],
          ),
          for (final f in _foods) _foodCard(f),
        ],
      ],
    );
  }

  Widget _foodCard(FoodToReview f) {
    final warnings = <String>[
      if (!f.macrosPlausible)
        'I macro sommano ${(f.proteinG + f.carbsG + f.fatG).round()} g su 100 g: impossibile.',
      if (!f.kcalPlausible)
        'Le calorie dichiarate (${f.kcal.round()}) non tornano con i macro '
            '(${f.kcalFromMacros.round()} kcal).',
    ];

    return SectionCard(
      title: f.name,
      subtitle: [
        if (f.brand != null && f.brand!.isNotEmpty) f.brand!,
        'di ${f.authorName}',
        if (f.barcode != null) 'codice ${f.barcode}',
      ].join(' · '),
      children: [
        Row(children: [
          _macro('kcal', f.kcal, primaryTeal),
          _macro('P', f.proteinG, colorP),
          _macro('C', f.carbsG, colorC),
          _macro('G', f.fatG, colorG),
        ]),
        if (f.servingLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Porzione: ${f.servingLabel}', style: TextStyle(color: textSecondary, fontSize: 12)),
          ),
        for (final w in warnings)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_outlined, size: 16, color: warningFg),
              const SizedBox(width: 6),
              Expanded(child: Text(w, style: TextStyle(color: warningFg, fontSize: 12))),
            ]),
          ),
        const SizedBox(height: 12),
        if (_busyId == f.id)
          Center(child: CircularProgressIndicator(color: primaryTeal))
        else if (f.isMine)
          Text('L\'hai creato tu: lo verifica un altro professionista.',
              style: TextStyle(color: textSecondary, fontSize: 12, fontStyle: FontStyle.italic))
        else
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _review(f, false),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Rifiuta'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _review(f, true),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Verifica'),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _macro(String label, double value, Color color) => Expanded(
        child: Column(children: [
          Text(value.round().toString(),
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: textSecondary, fontSize: 11)),
        ]),
      );
}
