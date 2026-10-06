import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/models.dart';
import '../../core/nutritionist_service.dart';

/// Dettaglio paziente per il nutrizionista: aderenza, diario con commenti,
/// nuovo commento e nuovo piano macro. Ogni sezione dipende dai consensi
/// del paziente: se manca, la RPC risponde 403 e la sezione lo spiega.
class PatientDetailScreen extends StatefulWidget {
  final PatientOverview patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textSecondary = Color(0xFF6B7280);

  late DateTime _to;
  late DateTime _from;

  AdherenceSummary? _summary;
  String? _summaryError;
  List<DiaryMealWithComments> _diary = [];
  String? _diaryError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _to = DateUtils.dateOnly(DateTime.now());
    _from = _to.subtract(const Duration(days: 6));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _summaryError = null;
      _diaryError = null;
    });
    // Le due sezioni dipendono da consensi diversi: una può fallire da sola
    await Future.wait([_loadSummary(), _loadDiary()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSummary() async {
    try {
      _summary = await NutritionistService.analyzeAdherence(widget.patient.patientId, _from, _to);
    } on AppError catch (e) {
      _summaryError = e.message;
    }
  }

  Future<void> _loadDiary() async {
    try {
      _diary = await NutritionistService.getDiaryWithComments(widget.patient.patientId, _from, _to);
    } on AppError catch (e) {
      _diaryError = e.message;
    }
  }

  Future<void> _addComment({DateTime? date, MealSlot? slot}) async {
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(slot == null ? 'Nuovo commento' : 'Commento su ${slot.label}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Scrivi un commento per il paziente'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Invia')),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty || !mounted) return;
    try {
      await NutritionistService.createComment(
        patientId: widget.patient.patientId,
        date: date ?? _to,
        body: body,
        slot: slot,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commento inviato.')));
      _load();
    } on AppError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _newPlan() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _MacroPlanForm(patient: widget.patient)),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Piano macro creato.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.patient.displayName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addComment(),
        backgroundColor: primaryTeal,
        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        label: const Text('Commenta', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text('Ultimi 7 giorni', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(color: primaryTeal),
            _buildSummary(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _newPlan,
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Imposta nuovo piano macro'),
            ),
            const SizedBox(height: 24),
            Text('Diario', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._buildDiary(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_summaryError != null) {
      return Text('Aderenza non disponibile: $_summaryError', style: const TextStyle(color: textSecondary));
    }
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    Widget tile(String label, String value) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTeal)),
                Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
              ]),
            ),
          ),
        );
    return Row(children: [
      tile('Aderenza', '${s.adherenceRate}%'),
      tile('Giorni registrati', '${s.loggedDays}/${s.totalDays}'),
      tile('In target', '${s.onTargetDays}'),
    ]);
  }

  List<Widget> _buildDiary() {
    if (_diaryError != null) {
      return [Text('Diario non disponibile: $_diaryError', style: const TextStyle(color: textSecondary))];
    }
    if (_diary.isEmpty && !_loading) {
      return const [Text('Nessuna registrazione nel periodo.', style: TextStyle(color: textSecondary))];
    }
    return [
      for (final meal in _diary)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      '${meal.date.day}/${meal.date.month} · ${meal.slot.label}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Commenta questo pasto',
                    icon: const Icon(Icons.add_comment_outlined, color: primaryTeal),
                    onPressed: () => _addComment(date: meal.date, slot: meal.slot),
                  ),
                ]),
                for (final e in meal.entries)
                  Text(
                    '${e['food_name'] ?? 'Alimento'} · ${(e['grams'] as num?)?.round() ?? 0} g · ${(e['kcal'] as num?)?.round() ?? 0} kcal',
                  ),
                for (final c in meal.comments)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.chat_bubble_outline, size: 16, color: primaryTeal),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c['body']?.toString() ?? '')),
                      if (c['read_at'] != null) const Icon(Icons.done_all, size: 16, color: primaryTeal),
                    ]),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

/// Form per un nuovo piano macro: target per pasto, uguali tutti i giorni.
class _MacroPlanForm extends StatefulWidget {
  final PatientOverview patient;

  const _MacroPlanForm({required this.patient});

  @override
  State<_MacroPlanForm> createState() => _MacroPlanFormState();
}

class _MacroPlanFormState extends State<_MacroPlanForm> {
  static const _slots = [MealSlot.breakfast, MealSlot.morningSnack, MealSlot.lunch, MealSlot.afternoonSnack, MealSlot.dinner];

  final _name = TextEditingController(text: 'Piano');
  final Map<MealSlot, List<TextEditingController>> _fields = {
    for (final s in _slots) s: [TextEditingController(), TextEditingController(), TextEditingController()],
  };
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    for (final list in _fields.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  double _val(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    final targets = <MealSlot, ({double protein, double carbs, double fat})>{};
    _fields.forEach((slot, c) {
      final p = _val(c[0]), carbs = _val(c[1]), f = _val(c[2]);
      if (p + carbs + f > 0) targets[slot] = (protein: p, carbs: carbs, fat: f);
    });
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci almeno un target.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await NutritionistService.startMacroPlan(
        patientId: widget.patient.patientId,
        name: _name.text.trim().isEmpty ? 'Piano' : _name.text.trim(),
        validFrom: DateTime.now(),
        targetsBySlot: targets,
      );
      if (mounted) Navigator.pop(context, true);
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String label) => InputDecoration(labelText: label, isDense: true);
    return Scaffold(
      appBar: AppBar(title: Text('Piano per ${widget.patient.displayName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome piano')),
          const SizedBox(height: 8),
          const Text('Grammi per pasto, validi tutti i giorni da oggi. Il piano attuale viene chiuso.'),
          const SizedBox(height: 16),
          for (final slot in _slots) ...[
            Text(slot.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              Expanded(child: TextField(controller: _fields[slot]![0], keyboardType: TextInputType.number, decoration: dec('Proteine'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _fields[slot]![1], keyboardType: TextInputType.number, decoration: dec('Carboidrati'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _fields[slot]![2], keyboardType: TextInputType.number, decoration: dec('Grassi'))),
            ]),
            const SizedBox(height: 16),
          ],
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Salvataggio...' : 'Crea piano')),
        ],
      ),
    );
  }
}
