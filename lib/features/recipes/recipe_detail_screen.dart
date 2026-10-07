import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/community_models.dart';
import '../../core/links.dart';
import '../../core/models.dart';
import '../../core/recipe_service.dart';
import '../../core/supabase.dart';
import 'recipe_editor_screen.dart';

/// Scheda di una ricetta: aggiunta al diario, gestione della propria ricetta
/// (modifica, invio in verifica, pubblicazione) e revisione del nutrizionista.
/// Restituisce `true` se la ricetta è stata registrata nel diario.
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId, this.initialSlot, this.date});

  final String recipeId;
  final MealSlot? initialSlot;
  final DateTime? date;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {


  Recipe? _recipe;
  Profile? _profile;
  bool _loading = true;
  String? _error;
  bool _busy = false;

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
      final recipe = await RecipeService.getRecipe(widget.recipeId);
      Profile? profile = _profile;
      if (profile == null) {
        try {
          profile = await AccountService.getProfile();
        } on AppError {
          // senza profilo si mostrano solo le azioni da paziente
        }
      }
      if (!mounted) return;
      setState(() {
        _recipe = recipe;
        _profile = profile;
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

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Esegue un'azione sulla ricetta con indicatore e messaggio d'esito.
  Future<void> _run(Future<void> Function() action, String successMessage, {bool popAfter = false}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _snack(successMessage);
      if (popAfter) {
        Navigator.pop(context, false);
        return;
      }
      await _load();
    } on AppError catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Azioni -------------------------------------------------------------

  Future<void> _addToDiary() async {
    final recipe = _recipe!;
    var slot = widget.initialSlot ?? MealSlot.forNow();
    var servings = 1.0;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aggiungi al diario',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 16),
                Text('Pasto', style: TextStyle(color: textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in MealSlot.values)
                      ChoiceChip(
                        label: Text(s.label),
                        selected: slot == s,
                        selectedColor: primaryTeal.withValues(alpha: 0.15),
                        onSelected: (_) => setSheet(() => slot = s),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text('Porzioni', style: TextStyle(color: textSecondary))),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: servings > 0.5 ? () => setSheet(() => servings -= 0.5) : null,
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(_fmtServings(servings),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: servings < 10 ? () => setSheet(() => servings += 0.5) : null,
                    ),
                  ],
                ),
                Text('${(recipe.kcalPerServing * servings).round()} kcal in totale',
                    style: TextStyle(color: textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Aggiungi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final count = await RecipeService.logToDiary(
        recipe.id,
        date: widget.date ?? DateTime.now(),
        slot: slot,
        servings: servings,
      );
      if (!mounted) return;
      _snack(count == 1 ? '1 alimento aggiunto' : '$count alimenti aggiunti');
      Navigator.pop(context, true);
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RecipeEditorScreen(recipeId: widget.recipeId)),
    );
    if (!mounted) return;
    if (saved == true) await _load();
  }

  Future<bool> _confirm(String title, String message, String confirmLabel, {bool destructive = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: destructive ? Colors.red : primaryTeal),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _delete() async {
    if (!await _confirm('Eliminare la ricetta?', 'La bozza verrà eliminata definitivamente.', 'Elimina',
        destructive: true)) {
      return;
    }
    if (!mounted) return;
    await _run(() => RecipeService.deleteDraft(widget.recipeId), 'Ricetta eliminata', popAfter: true);
  }

  Future<void> _publish() async {
    final onlyMyPatients = await showDialog<bool>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pubblica la ricetta'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, true),
            child: const ListTile(
              leading: Icon(Icons.people_outline),
              title: Text('Solo i miei pazienti'),
              subtitle: Text('Visibile ai pazienti collegati a te'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, false),
            child: const ListTile(
              leading: Icon(Icons.public),
              title: Text('Tutti'),
              subtitle: Text('Visibile a tutti gli utenti dell\'app'),
            ),
          ),
        ],
      ),
    );
    if (onlyMyPatients == null || !mounted) return;
    await _run(() => RecipeService.publishOwn(widget.recipeId, onlyMyPatients: onlyMyPatients), 'Ricetta pubblicata');
  }

  Future<void> _submit() async {
    if (!await _confirm(
        'Inviare al nutrizionista?',
        'Il tuo nutrizionista verificherà la ricetta. Finché è in revisione non potrai modificarla.',
        'Invia')) {
      return;
    }
    if (!mounted) return;
    await _run(() => RecipeService.submitForReview(widget.recipeId), 'Ricetta inviata per la verifica');
  }

  Future<void> _withdraw() =>
      _run(() => RecipeService.withdraw(widget.recipeId), 'Ricetta ritirata: è di nuovo una bozza');

  Future<void> _unpublish() async {
    if (!await _confirm('Ritirare la pubblicazione?', 'La ricetta non sarà più visibile agli altri utenti.', 'Ritira')) {
      return;
    }
    if (!mounted) return;
    await _run(() => RecipeService.unpublishOwn(widget.recipeId), 'Pubblicazione ritirata');
  }

  Future<void> _approve() async {
    if (!await _confirm('Approvare la ricetta?', 'La ricetta diventerà visibile al paziente e potrà usarla nel diario.',
        'Approva')) {
      return;
    }
    if (!mounted) return;
    await _run(() => RecipeService.review(widget.recipeId, approve: true), 'Ricetta approvata');
  }

  Future<void> _requestChanges() async {
    final notes = await showDialog<String>(context: context, builder: (_) => const _NotesDialog());
    if (notes == null || !mounted) return;
    await _run(() => RecipeService.review(widget.recipeId, approve: false, notes: notes), 'Richiesta di modifiche inviata');
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Ricetta', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _recipe == null) return Center(child: CircularProgressIndicator(color: primaryTeal));
    if (_error != null && _recipe == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
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
    final r = _recipe!;
    final tags = [
      for (final t in r.restrictionTags) dietaryRestrictionLabels[t] ?? t,
      for (final t in r.goalTags) goalTagLabels[t] ?? t,
    ];
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (!r.isApproved) ...[
              Align(alignment: Alignment.centerLeft, child: _statusChip(r)),
              const SizedBox(height: 8),
            ],
            Text(r.title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary)),
            if (r.authorName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text('di ${r.authorName}', style: TextStyle(color: textSecondary, fontSize: 14)),
                  ),
                  if (r.isApproved) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.verified, size: 15, color: primaryTeal),
                    const SizedBox(width: 2),
                    Text('Verificata',
                        style: TextStyle(color: primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ],
            if (r.description != null) ...[
              const SizedBox(height: 12),
              Text(r.description!, style: TextStyle(color: textPrimary, fontSize: 15, height: 1.4)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (r.prepMinutes != null) _info(Icons.schedule, '${r.prepMinutes} min'),
                _info(Icons.restaurant, r.servings == 1 ? '1 porzione' : '${r.servings} porzioni'),
                if (r.slots.isNotEmpty) _info(Icons.wb_sunny_outlined, r.slots.map((s) => s.label).join(', ')),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tags) _tag(t)]),
            ],
            if (r.status == 'rejected' && r.reviewNotes != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: warningBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Text('Note del nutrizionista: ${r.reviewNotes}',
                    style: const TextStyle(color: Color(0xFF9A3412), height: 1.4)),
              ),
            ],
            const SizedBox(height: 16),
            _buildMacros(r),
            if (r.socialUrl != null) ...[
              const SizedBox(height: 12),
              _buildSocialButton(r.socialUrl!),
            ],
            const SizedBox(height: 20),
            _sectionTitle('Ingredienti'),
            const SizedBox(height: 8),
            _card(
              child: r.ingredients.isEmpty
                  ? Text('Nessun ingrediente.', style: TextStyle(color: textSecondary))
                  : Column(
                      children: [
                        for (var i = 0; i < r.ingredients.length; i++) ...[
                          if (i > 0) Divider(height: 16, color: borderColor),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.ingredients[i].food.name,
                                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                                    if (r.ingredients[i].note != null)
                                      Text(r.ingredients[i].note!,
                                          style: TextStyle(color: textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text('${_fmtGrams(r.ingredients[i].grams)} g',
                                  style: TextStyle(color: textSecondary)),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
            if (r.instructions != null) ...[
              const SizedBox(height: 20),
              _sectionTitle('Procedimento'),
              const SizedBox(height: 8),
              _card(child: Text(r.instructions!, style: TextStyle(color: textPrimary, height: 1.5))),
            ],
            const SizedBox(height: 24),
            ..._buildActions(r),
          ],
        ),
        if (_busy || _loading)
          Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(color: primaryTeal)),
      ],
    );
  }

  List<Widget> _buildActions(Recipe r) {
    final uid = supabase.auth.currentUser?.id;
    final isOwner = uid != null && r.authorId == uid;
    final profile = _profile;
    final isVerifiedNutritionist = profile != null && profile.isNutritionist && profile.professionalVerified;
    final isNutritionistOwner = isOwner && profile != null && profile.isNutritionist;
    final actions = <Widget>[];

    if (r.isApproved) {
      actions.add(_primaryButton(Icons.add, 'Aggiungi al diario', _addToDiary));
    }
    if (isOwner && r.isEditable) {
      if (isVerifiedNutritionist) {
        actions.add(_primaryButton(Icons.publish, 'Pubblica', _publish));
      } else if (profile != null && profile.isNutritionist) {
        actions.add(Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Potrai pubblicare le tue ricette dopo la verifica del profilo professionale.',
              style: TextStyle(color: textSecondary, fontSize: 13)),
        ));
      } else {
        actions.add(_primaryButton(Icons.send, 'Invia al nutrizionista per la verifica', _submit));
      }
      actions.add(_secondaryButton(Icons.edit_outlined, 'Modifica', _edit));
      actions.add(_secondaryButton(Icons.delete_outline, 'Elimina', _delete, color: Colors.red));
    }
    if (isOwner && r.status == 'pending_review') {
      actions.add(Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('La ricetta è in attesa della verifica del tuo nutrizionista.',
            style: TextStyle(color: textSecondary, fontSize: 13)),
      ));
      actions.add(_secondaryButton(Icons.undo, 'Ritira', _withdraw));
    }
    if (isNutritionistOwner && r.isApproved) {
      actions.add(_secondaryButton(Icons.visibility_off_outlined, 'Ritira pubblicazione', _unpublish));
    }
    if (!isOwner && r.status == 'pending_review') {
      actions.add(_primaryButton(Icons.check, 'Approva', _approve));
      actions.add(_secondaryButton(Icons.rate_review_outlined, 'Chiedi modifiche', _requestChanges));
    }
    return actions;
  }

  Widget _primaryButton(IconData icon, String label, VoidCallback onPressed) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: primaryTeal,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _busy ? null : onPressed,
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
      );

  Widget _secondaryButton(IconData icon, String label, VoidCallback onPressed, {Color? color}) {
    final c = color ?? primaryTeal;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: c,
              side: BorderSide(color: c.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _busy ? null : onPressed,
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
      );
  }

  Widget _buildSocialButton(String url) {
    final style = socialLinkStyle(url);
    final label = style.label == 'Link' ? 'Apri il link' : 'Guarda su ${style.label}';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: cardColor,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => openExternalLink(context, url),
        icon: Icon(style.icon),
        label: Text(label),
      ),
    );
  }

  Widget _buildMacros(Recipe r) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Per porzione', style: TextStyle(color: textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Text('${r.kcalPerServing.round()} kcal',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _macro('Proteine', r.proteinPerServing, colorP)),
              Expanded(child: _macro('Carboidrati', r.carbsPerServing, colorC)),
              Expanded(child: _macro('Grassi', r.fatPerServing, colorG)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macro(String label, double value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${value.round()} g', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(color: textSecondary, fontSize: 12)),
        ],
      );

  Widget _statusChip(Recipe r) {
    final color = switch (r.status) {
      'pending_review' => colorC,
      'rejected' => colorG,
      _ => textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(r.statusLabel, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _info(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textSecondary),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: textSecondary, fontSize: 13)),
        ],
      );

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: primaryTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: TextStyle(color: primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _sectionTitle(String text) =>
      Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary));

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

  static String _fmtServings(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static String _fmtGrams(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Dialog per le note obbligatorie quando si chiedono modifiche.
class _NotesDialog extends StatefulWidget {
  const _NotesDialog();

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final notes = _controller.text.trim();
    if (notes.isEmpty) {
      setState(() => _errorText = 'Scrivi cosa va corretto');
      return;
    }
    Navigator.pop(context, notes);
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return AlertDialog(
      title: const Text('Chiedi modifiche'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        maxLength: 1000,
        decoration: InputDecoration(
          hintText: 'Cosa deve correggere il paziente?',
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF127B6D)),
          onPressed: _submit,
          child: const Text('Invia'),
        ),
      ],
    );
  }
}
