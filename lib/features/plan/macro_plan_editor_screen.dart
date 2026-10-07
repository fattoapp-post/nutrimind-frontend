import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/models.dart';
import '../../core/plan_service.dart';
import '../../core/theme.dart';

/// Editor di un piano macro. Lo usano due persone diverse:
///
/// * il professionista per un suo paziente ([patientId] valorizzato):
///   scrive anche le istruzioni, cioè come va seguito il piano;
/// * il paziente per sé, quando non è seguito da nessuno
///   ([patientId] nullo): è l'autogestione.
///
/// Si parte dalle calorie e dalla ripartizione dei macro, che riempiono
/// la griglia per pasto; poi ogni pasto si può correggere a mano.
class MacroPlanEditorScreen extends StatefulWidget {
  /// Null = piano per sé.
  final String? patientId;

  /// Nome mostrato nel titolo quando si lavora per un paziente.
  final String? patientName;

  /// Piano in corso da cui partire.
  final MacroPlan? current;

  const MacroPlanEditorScreen({super.key, this.patientId, this.patientName, this.current});

  @override
  State<MacroPlanEditorScreen> createState() => _MacroPlanEditorScreenState();
}

class _MacroPlanEditorScreenState extends State<MacroPlanEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  final _kcal = TextEditingController(text: '2000');
  final _protein = TextEditingController(text: '30');
  final _carbs = TextEditingController(text: '40');
  final _fat = TextEditingController(text: '30');

  final Map<MealSlot, MealTarget> _targets = {};
  bool _saving = false;
  String? _error;

  bool get _forPatient => widget.patientId != null;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _name = TextEditingController(text: current?.name ?? (_forPatient ? 'Piano' : 'I miei obiettivi'));
    _notes = TextEditingController(text: current?.notes ?? '');
    if (current != null && current.targets.isNotEmpty) {
      _targets.addAll(current.targets);
      _kcal.text = current.kcal.round().toString();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _notes, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  double get _pctTotal => _num(_protein) + _num(_carbs) + _num(_fat);

  void _distribute() {
    final kcal = _num(_kcal);
    if (kcal <= 0) {
      setState(() => _error = 'Scrivi quante calorie al giorno.');
      return;
    }
    if ((_pctTotal - 100).abs() > 0.5) {
      setState(() => _error = 'Le percentuali dei macro devono sommare a 100 (ora ${_pctTotal.round()}).');
      return;
    }
    setState(() {
      _error = null;
      _targets
        ..clear()
        ..addAll(PlanService.distribute(
          kcal: kcal,
          proteinPct: _num(_protein),
          carbsPct: _num(_carbs),
          fatPct: _num(_fat),
        ));
    });
  }

  double get _totalKcal => _targets.values.fold(0.0, (s, t) => s + t.kcal);

  Future<void> _save() async {
    if (_targets.values.every((t) => t.isEmpty)) {
      setState(() => _error = 'Imposta almeno un pasto.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PlanService.savePlan(
        patientId: widget.patientId,
        name: _name.text.trim().isEmpty ? 'Piano' : _name.text.trim(),
        targets: _targets,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_forPatient ? 'Piano per ${widget.patientName ?? 'il paziente'}' : 'I miei obiettivi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            title: 'Punto di partenza',
            subtitle: 'Calorie al giorno e ripartizione dei macro. '
                'Premendo "Distribuisci" i valori finiscono nei pasti qui sotto, dove si possono correggere.',
            children: [
              TextField(
                controller: _kcal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'kcal al giorno', isDense: true),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _pctField(_protein, 'Proteine %', colorP)),
                const SizedBox(width: 8),
                Expanded(child: _pctField(_carbs, 'Carbo %', colorC)),
                const SizedBox(width: 8),
                Expanded(child: _pctField(_fat, 'Grassi %', colorG)),
              ]),
              const SizedBox(height: 8),
              Text(
                (_pctTotal - 100).abs() < 0.5
                    ? 'Somma: 100%'
                    : 'Somma: ${_pctTotal.round()}% — deve fare 100',
                style: TextStyle(
                  color: (_pctTotal - 100).abs() < 0.5 ? primaryTeal : colorG,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _distribute,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Distribuisci sui pasti'),
              ),
            ],
          ),
          _card(
            title: 'Obiettivi per pasto',
            subtitle: 'Grammi, uguali tutti i giorni. Un pasto lasciato a zero non viene conteggiato.',
            children: [
              for (final slot in PlanService.planSlots) _slotRow(slot),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Totale giornata', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                  Text('${_totalKcal.round()} kcal',
                      style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'P ${_sum((t) => t.proteinG).round()} g · '
                'C ${_sum((t) => t.carbsG).round()} g · '
                'G ${_sum((t) => t.fatG).round()} g',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ],
          ),
          _card(
            title: _forPatient ? 'Come seguire il piano' : 'Promemoria per me',
            subtitle: _forPatient
                ? 'Il paziente lo legge nel diario, sopra gli obiettivi. '
                    'Qui si spiega il metodo: ordine dei pasti, sostituzioni ammesse, cosa fare fuori casa.'
                : 'Una nota che ritrovi nel diario.',
            children: [
              TextField(
                controller: _notes,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'Es. "Pesa gli alimenti a crudo. Puoi scambiare il pranzo con la cena. '
                      'Fuori casa: una porzione di proteine più un contorno."',
                  isDense: true,
                ),
              ),
            ],
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome del piano', isDense: true),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: colorG)),
            const SizedBox(height: 8),
          ],
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvataggio…' : 'Salva il piano'),
          ),
          const SizedBox(height: 8),
          Text(
            'Il piano attuale viene chiuso da oggi e sostituito da questo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  double _sum(double Function(MealTarget) pick) => _targets.values.fold(0.0, (s, t) => s + pick(t));

  Widget _pctField(TextEditingController c, String label, Color color) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: color),
          isDense: true,
        ),
      );

  Widget _slotRow(MealSlot slot) {
    final target = _targets[slot] ?? const MealTarget();
    Widget field(String label, double value, void Function(double) apply) => Expanded(
          child: TextFormField(
            key: ValueKey('${slot.value}_$label${value.round()}'),
            initialValue: value == 0 ? '' : value.round().toString(),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label, isDense: true),
            onChanged: (v) => setState(() => apply(double.tryParse(v.replaceAll(',', '.')) ?? 0)),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${slot.label} · ${slot.time}',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
              Text(target.isEmpty ? '—' : '${target.kcal.round()} kcal',
                  style: TextStyle(color: textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            field('P', target.proteinG, (v) => _targets[slot] = target.copyWith(proteinG: v)),
            const SizedBox(width: 8),
            field('C', target.carbsG, (v) => _targets[slot] = target.copyWith(carbsG: v)),
            const SizedBox(width: 8),
            field('G', target.fatG, (v) => _targets[slot] = target.copyWith(fatG: v)),
          ]),
        ],
      ),
    );
  }

  Widget _card({required String title, String? subtitle, required List<Widget> children}) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 13)),
              ),
            ...children,
          ],
        ),
      );
}
