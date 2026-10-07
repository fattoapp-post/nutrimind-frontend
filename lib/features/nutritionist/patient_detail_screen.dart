import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/models.dart';
import '../../core/community_models.dart';
import '../../core/nutritionist_service.dart';
import '../../core/plan_service.dart';
import '../../core/recipe_service.dart';
import '../plan/macro_plan_editor_screen.dart';
import 'suggest_to_patient_sheet.dart';

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

  int _rangeDays = 7;
  late DateTime _to;
  late DateTime _from;

  AdherenceSummary? _summary;
  String? _summaryError;
  List<DiaryMealWithComments> _diary = [];
  String? _diaryError;
  PatientSettings? _settings;
  MacroPlan? _plan;
  List<PatientSuggestion> _suggestions = const [];
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
      _plan = await PlanService.getCurrentPlan(patientId: widget.patient.patientId);
    } on AppError {
      _plan = null;
    }
    try {
      _suggestions = await SuggestionService.list(patientId: widget.patient.patientId);
    } on AppError {
      _suggestions = const [];
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
      MaterialPageRoute(
        builder: (_) => MacroPlanEditorScreen(
          patientId: widget.patient.patientId,
          patientName: widget.patient.displayName,
          current: _plan,
        ),
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Piano macro creato.')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
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
            if (_loading) LinearProgressIndicator(color: primaryTeal),
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
            _buildSuggestions(),
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
      return Text('Aderenza non disponibile: $_summaryError', style: TextStyle(color: textSecondary));
    }
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    Widget tile(String label, String value) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTeal)),
                Text(label, style: TextStyle(color: textSecondary, fontSize: 12)),
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
        leading: Icon(Icons.no_food_outlined, color: primaryTeal),
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

  Future<void> _addSuggestion() async {
    final added = await SuggestToPatientSheet.show(
      context,
      patientId: widget.patient.patientId,
      patientName: widget.patient.displayName,
    );
    if (added == true && mounted) _load();
  }

  Future<void> _removeSuggestion(PatientSuggestion s) async {
    try {
      await SuggestionService.remove(s.id);
      if (mounted) _load();
    } on AppError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Le ricette pubblicate valgono per tutti i pazienti; qui stanno le
  /// indicazioni per questa persona, con la nota del perché.
  Widget _buildSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Consigli per ${widget.patient.displayName}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            TextButton.icon(
              onPressed: _addSuggestion,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Aggiungi'),
            ),
          ],
        ),
        if (_suggestions.isEmpty)
          Card(
            child: ListTile(
              leading: Icon(Icons.lightbulb_outline, color: textSecondary),
              title: const Text('Nessun consiglio mirato'),
              subtitle: Text(
                'Una ricetta o un alimento scelti per lui, oltre a quelli che pubblichi per tutti.',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ),
          )
        else
          for (final s in _suggestions)
            Card(
              child: ListTile(
                leading: Icon(s.isRecipe ? Icons.menu_book_outlined : Icons.restaurant, color: primaryTeal),
                title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [
                    '${s.kcal.round()} kcal per ${s.portionLabel}',
                    if (s.note != null) s.note!,
                  ].join(' · '),
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                trailing: IconButton(
                  tooltip: 'Togli il consiglio',
                  icon: Icon(Icons.close, color: textSecondary, size: 20),
                  onPressed: () => _removeSuggestion(s),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildPlan() {
    final plan = _plan;
    if (plan == null) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.assignment_late_outlined, color: textSecondary),
          title: Text('Nessun piano attivo'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.assignment_outlined, color: primaryTeal),
              const SizedBox(width: 8),
              Expanded(child: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold))),
              Text('${plan.kcal.round()} kcal/giorno', style: TextStyle(color: textSecondary)),
            ]),
            if (plan.validFrom != null)
              Text('Dal ${plan.validFrom!.day}/${plan.validFrom!.month}/${plan.validFrom!.year}',
                  style: TextStyle(color: textSecondary, fontSize: 12)),
            if (plan.isSelfManaged)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Impostato dal paziente prima di collegarsi a te',
                    style: TextStyle(color: textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 8),
            for (final slot in PlanService.planSlots)
              if (plan.targets[slot] != null && !plan.targets[slot]!.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${slot.label}: P ${plan.targets[slot]!.proteinG.round()} · '
                    'C ${plan.targets[slot]!.carbsG.round()} · '
                    'G ${plan.targets[slot]!.fatG.round()} g · '
                    '${plan.targets[slot]!.kcal.round()} kcal',
                  ),
                ),
            if (plan.notes != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tealSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Come seguirlo',
                        style: TextStyle(color: primaryTeal, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(plan.notes!, style: TextStyle(color: textPrimary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDiary() {
    if (_diaryError != null) {
      return [Text('Diario non disponibile: $_diaryError', style: TextStyle(color: textSecondary))];
    }
    if (_diary.isEmpty && !_loading) {
      return [Text('Nessuna registrazione nel periodo.', style: TextStyle(color: textSecondary))];
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
                    icon: Icon(Icons.add_comment_outlined, color: primaryTeal),
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
                      Icon(Icons.chat_bubble_outline, size: 16, color: primaryTeal),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c['body']?.toString() ?? '')),
                      if (c['read_at'] != null) Icon(Icons.done_all, size: 16, color: primaryTeal),
                    ]),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

