import 'package:flutter/material.dart';

import '../../core/account_service.dart';
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

  int _rangeDays = 7;
  late DateTime _to;
  late DateTime _from;

  AdherenceSummary? _summary;
  String? _summaryError;
  List<DiaryMealWithComments> _diary = [];
  String? _diaryError;
  PatientSettings? _settings;
  ({String name, DateTime? validFrom, List<Map<String, dynamic>> targets})? _plan;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _setRange(7);
    _load();
  }

  void _setRange(int days) {
    _rangeDays = days;
    _to = DateUtils.dateOnly(DateTime.now());
    _from = _to.subtract(Duration(days: days - 1));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _summaryError = null;
      _diaryError = null;
    });
    // Le sezioni dipendono da consensi diversi: ognuna può fallire da sola
    await Future.wait([_loadSummary(), _loadDiary(), _loadProfileAndPlan()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfileAndPlan() async {
    try {
      _settings = await NutritionistService.getPatientSettings(widget.patient.patientId);
    } on AppError {
      _settings = null; // consenso `profile` non concesso
    }
    try {
      _plan = await NutritionistService.getCurrentPlan(widget.patient.patientId);
    } on AppError {
      _plan = null;
    }
  }

  Future<void> _revokeLink() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Scollegare ${widget.patient.displayName}?'),
        content: const Text('Non vedrai più i suoi dati. Per ricollegarvi servirà un nuovo codice invito.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Scollega')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AccountService.revokeLink(widget.patient.linkId);
      if (mounted) Navigator.pop(context, true);
    } on AppError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patient.displayName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'revoke') _revokeLink();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'revoke', child: Text('Scollega paziente')),
            ],
          ),
        ],
      ),
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
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 giorni')),
                ButtonSegment(value: 30, label: Text('30 giorni')),
              ],
              selected: {_rangeDays},
              onSelectionChanged: (v) {
                setState(() => _setRange(v.first));
                _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(color: primaryTeal),
            _buildSummary(),
            const SizedBox(height: 16),
            _buildRestrictions(),
            const SizedBox(height: 16),
            _buildPlan(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _newPlan,
              icon: const Icon(Icons.assignment_outlined),
              label: Text(_plan == null ? 'Imposta piano macro' : 'Imposta nuovo piano macro'),
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

  Widget _buildRestrictions() {
    final s = _settings;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.no_food_outlined, color: primaryTeal),
        title: const Text('Restrizioni alimentari'),
        subtitle: Text(
          s == null
              ? 'Non condivise dal paziente (consenso "Restrizioni alimentari").'
              : s.dietaryRestrictions.isEmpty
                  ? 'Nessuna restrizione indicata.'
                  : s.dietaryRestrictions.map((r) => dietaryRestrictionLabels[r] ?? r).join(', '),
        ),
      ),
    );
  }

  Widget _buildPlan() {
    final plan = _plan;
    if (plan == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.assignment_late_outlined, color: textSecondary),
          title: Text('Nessun piano attivo'),
        ),
      );
    }
    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;
    final allDays = plan.targets.where((t) => t['day_of_week'] == null).toList();
    final rows = allDays.isNotEmpty ? allDays : plan.targets;
    final kcal = rows.fold(0.0, (s, t) => s + n(t['protein_g']) * 4 + n(t['carbs_g']) * 4 + n(t['fat_g']) * 9);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.assignment_outlined, color: primaryTeal),
              const SizedBox(width: 8),
              Expanded(child: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold))),
              Text('${kcal.round()} kcal/giorno', style: const TextStyle(color: textSecondary)),
            ]),
            if (plan.validFrom != null)
              Text('Dal ${plan.validFrom!.day}/${plan.validFrom!.month}/${plan.validFrom!.year}',
                  style: const TextStyle(color: textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            for (final t in rows)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${MealSlot.fromValue(t['meal_slot'] as String?).label}: '
                  'P ${n(t['protein_g']).round()} · C ${n(t['carbs_g']).round()} · G ${n(t['fat_g']).round()} g',
                ),
              ),
          ],
        ),
      ),
    );
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
