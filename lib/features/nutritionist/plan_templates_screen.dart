import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_error.dart';
import '../../core/community_models.dart';
import '../../core/directory_service.dart';
import '../../core/models.dart';

/// Piani alimentari "di base" del nutrizionista, mostrati nella sua pagina
/// pubblica.
class PlanTemplatesScreen extends StatefulWidget {
  const PlanTemplatesScreen({super.key});

  @override
  State<PlanTemplatesScreen> createState() => _PlanTemplatesScreenState();
}

/// Copia di un piano con la pubblicazione cambiata (il modello non ha copyWith).
PlanTemplate _withPublished(PlanTemplate p, bool published) => PlanTemplate(
  id: p.id,
  title: p.title,
  description: p.description,
  goalTags: p.goalTags,
  restrictionTags: p.restrictionTags,
  kcal: p.kcal,
  proteinG: p.proteinG,
  carbsG: p.carbsG,
  fatG: p.fatG,
  durationWeeks: p.durationWeeks,
  priceLabel: p.priceLabel,
  isPublished: published,
);

class _PlanTemplatesScreenState extends State<PlanTemplatesScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color colorP = Color(0xFF5A44F2);
  static const Color colorC = Color(0xFFF0A500);
  static const Color colorG = Color(0xFFEB5A0C);

  List<PlanTemplate> _plans = [];
  bool _loading = true;
  String? _error;
  final Set<String> _toggling = {};

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
      final plans = await DirectoryService.getMyPlans();
      if (mounted) setState(() => _plans = plans);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _togglePublished(PlanTemplate p, bool value) async {
    final id = p.id;
    if (id == null) return;
    final updated = _withPublished(p, value);
    setState(() {
      _toggling.add(id);
      _plans = [for (final x in _plans) x.id == id ? updated : x];
    });
    try {
      await DirectoryService.savePlan(updated);
      if (!mounted) return;
      _snack(value ? 'Piano pubblicato' : 'Piano nascosto dalla pagina pubblica');
    } on AppError catch (e) {
      if (!mounted) return;
      // Ripristina lo stato precedente
      setState(() => _plans = [for (final x in _plans) x.id == id ? p : x]);
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _toggling.remove(id));
    }
  }

  Future<void> _edit([PlanTemplate? plan]) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => _PlanFormScreen(plan: plan)));
    if (saved == true && mounted) _load();
  }

  Future<void> _delete(PlanTemplate p) async {
    final id = p.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare il piano?'),
        content: Text('"${p.title}" verrà rimosso anche dalla tua pagina pubblica.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await DirectoryService.deletePlan(id);
      if (!mounted) return;
      setState(() => _plans = _plans.where((x) => x.id != id).toList());
      _snack('Piano eliminato');
    } on AppError catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          'Piani di base',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo piano'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryTeal))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: textSecondary)),
                  TextButton(onPressed: _load, child: const Text('Riprova')),
                ],
              ),
            )
          : RefreshIndicator(
              color: primaryTeal,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  if (_plans.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Non hai ancora creato piani di base.\nTocca "Nuovo piano" per iniziare.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary),
                      ),
                    )
                  else
                    for (final p in _plans) ...[_buildPlanCard(p), const SizedBox(height: 12)],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryTeal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryTeal.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: primaryTeal),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'I piani pubblicati compaiono nella tua pagina pubblica, visibile ai pazienti che cercano un nutrizionista.',
              style: TextStyle(color: textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: primaryTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: const TextStyle(color: primaryTeal, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _macro(String label, double grams, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label ${grams.round()} g', style: const TextStyle(color: textPrimary, fontSize: 13)),
      ],
    );
  }

  Widget _buildPlanCard(PlanTemplate p) {
    final tags = [
      for (final g in p.goalTags) goalTagLabels[g] ?? g,
      for (final r in p.restrictionTags) dietaryRestrictionLabels[r] ?? r,
    ];
    final details = [
      if (p.kcal != null) '${p.kcal!.round()} kcal/giorno',
      if (p.durationWeeks != null) p.durationWeeks == 1 ? '1 settimana' : '${p.durationWeeks} settimane',
      if (p.priceLabel != null) p.priceLabel!,
    ].join(' · ');
    final toggling = _toggling.contains(p.id);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.isPublished ? 'Pubblicato' : 'Non pubblicato',
                      style: TextStyle(color: p.isPublished ? primaryTeal : textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: p.isPublished,
                activeThumbColor: primaryTeal,
                onChanged: toggling ? null : (v) => _togglePublished(p, v),
              ),
            ],
          ),
          if (p.description != null) ...[
            const SizedBox(height: 6),
            Text(
              p.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: textSecondary),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(details, style: const TextStyle(color: textPrimary, fontSize: 13)),
          ],
          if (p.proteinG != null || p.carbsG != null || p.fatG != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (p.proteinG != null) _macro('P', p.proteinG!, colorP),
                if (p.carbsG != null) _macro('C', p.carbsG!, colorC),
                if (p.fatG != null) _macro('G', p.fatG!, colorG),
              ],
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tags) _tag(t)]),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _delete(p),
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade700),
                label: Text('Elimina', style: TextStyle(color: Colors.red.shade700)),
              ),
              TextButton.icon(
                onPressed: () => _edit(p),
                icon: const Icon(Icons.edit_outlined, size: 18, color: primaryTeal),
                label: const Text('Modifica', style: TextStyle(color: primaryTeal)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Creazione o modifica di un piano di base. Restituisce true se salvato.
class _PlanFormScreen extends StatefulWidget {
  const _PlanFormScreen({this.plan});

  final PlanTemplate? plan;

  @override
  State<_PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<_PlanFormScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.plan?.title ?? '');
  late final _description = TextEditingController(text: widget.plan?.description ?? '');
  late final _kcal = TextEditingController(text: _fmt(widget.plan?.kcal));
  late final _protein = TextEditingController(text: _fmt(widget.plan?.proteinG));
  late final _carbs = TextEditingController(text: _fmt(widget.plan?.carbsG));
  late final _fat = TextEditingController(text: _fmt(widget.plan?.fatG));
  late final _weeks = TextEditingController(text: widget.plan?.durationWeeks?.toString() ?? '');
  late final _price = TextEditingController(text: widget.plan?.priceLabel ?? '');
  late final Set<String> _goals = {...?widget.plan?.goalTags};
  late final Set<String> _restrictions = {...?widget.plan?.restrictionTags};
  late bool _published = widget.plan?.isPublished ?? false;
  bool _saving = false;

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.round().toString() : v.toString();
  }

  static double? _parseDouble(String s) {
    final t = s.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  static String? _textOrNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _kcal, _protein, _carbs, _fat, _weeks, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final weeks = _weeks.text.trim();
    final plan = PlanTemplate(
      id: widget.plan?.id,
      title: _title.text.trim(),
      description: _textOrNull(_description.text),
      goalTags: goalTagLabels.keys.where(_goals.contains).toList(),
      restrictionTags: dietaryRestrictionLabels.keys.where(_restrictions.contains).toList(),
      kcal: _parseDouble(_kcal.text),
      proteinG: _parseDouble(_protein.text),
      carbsG: _parseDouble(_carbs.text),
      fatG: _parseDouble(_fat.text),
      durationWeeks: weeks.isEmpty ? null : int.tryParse(weeks),
      priceLabel: _textOrNull(_price.text),
      isPublished: _published,
    );
    try {
      await DirectoryService.savePlan(plan);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint, String? suffix}) => InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: primaryTeal),
    ),
  );

  /// Campo numerico facoltativo, con limite superiore ragionevole.
  Widget _numberField(TextEditingController c, String label, String suffix, double max, {bool integer = false}) {
    return TextFormField(
      controller: c,
      decoration: _decoration(label, suffix: suffix),
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(integer ? r'[0-9]' : r'[0-9.,]'))],
      validator: (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        final n = integer ? int.tryParse(t)?.toDouble() : _parseDouble(t);
        if (n == null || n < 0) return 'Valore non valido';
        if (integer && n < 1) return 'Minimo 1';
        if (n > max) return 'Massimo ${max.round()}';
        return null;
      },
    );
  }

  Widget _chips(Map<String, String> labels, Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in labels.entries)
          FilterChip(
            label: Text(e.value),
            selected: selected.contains(e.key),
            showCheckmark: false,
            selectedColor: primaryTeal,
            backgroundColor: Colors.white,
            side: BorderSide(color: selected.contains(e.key) ? primaryTeal : Colors.grey.shade200),
            labelStyle: TextStyle(color: selected.contains(e.key) ? Colors.white : textPrimary),
            onSelected: (v) => setState(() => v ? selected.add(e.key) : selected.remove(e.key)),
          ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final editing = widget.plan?.id != null;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          editing ? 'Modifica piano' : 'Nuovo piano',
          style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _title,
              decoration: _decoration('Titolo *', hint: 'Es. Piano dimagrimento base'),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Inserisci un titolo' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              decoration: _decoration('Descrizione', hint: 'A chi è rivolto, cosa include…'),
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
            ),
            const SizedBox(height: 16),
            _label('Obiettivi'),
            _chips(goalTagLabels, _goals),
            const SizedBox(height: 16),
            _label('Adatto a'),
            _chips(dietaryRestrictionLabels, _restrictions),
            const SizedBox(height: 20),
            _label('Valori indicativi giornalieri'),
            _numberField(_kcal, 'Calorie', 'kcal', 10000),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField(_protein, 'Proteine', 'g', 1000)),
                const SizedBox(width: 8),
                Expanded(child: _numberField(_carbs, 'Carboidrati', 'g', 1000)),
                const SizedBox(width: 8),
                Expanded(child: _numberField(_fat, 'Grassi', 'g', 1000)),
              ],
            ),
            const SizedBox(height: 20),
            _label('Durata e prezzo'),
            Row(
              children: [
                Expanded(child: _numberField(_weeks, 'Durata', 'settimane', 104, integer: true)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _price,
                    decoration: _decoration('Prezzo', hint: 'da 60 €/mese'),
                    maxLength: 60,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SwitchListTile(
                value: _published,
                activeThumbColor: primaryTeal,
                onChanged: (v) => setState(() => _published = v),
                title: const Text('Pubblicato', style: TextStyle(color: textPrimary)),
                subtitle: const Text('Visibile nella tua pagina pubblica', style: TextStyle(color: textSecondary)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Salva'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
