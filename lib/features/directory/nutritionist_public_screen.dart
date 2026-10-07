import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/chat_service.dart';
import '../../core/community_models.dart';
import '../../core/directory_service.dart';
import '../../core/links.dart';
import '../../core/models.dart';
import '../../core/recipe_service.dart';
import '../../core/supabase.dart';
import '../chat/chat_screen.dart';
import '../recipes/recipe_detail_screen.dart';

/// Pagina pubblica di un nutrizionista: presentazione, piani di base e
/// ricette pubblicate.
class NutritionistPublicScreen extends StatefulWidget {
  const NutritionistPublicScreen({super.key, required this.card});

  final NutritionistCard card;

  @override
  State<NutritionistPublicScreen> createState() => _NutritionistPublicScreenState();
}

class _NutritionistPublicScreenState extends State<NutritionistPublicScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color colorP = Color(0xFF5A44F2);
  static const Color colorC = Color(0xFFF0A500);
  static const Color colorG = Color(0xFFEB5A0C);

  List<PlanTemplate> _plans = [];
  bool _plansLoading = true;
  String? _plansError;

  List<Recipe> _recipes = [];
  bool _recipesLoading = true;
  String? _recipesError;

  bool _starting = false;

  NutritionistCard get card => widget.card;
  bool get _isMe => supabase.auth.currentUser?.id == card.id;
  bool get _canWrite => !_isMe && (card.acceptingPatients || card.isMyNutritionist);

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadRecipes();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _plansLoading = true;
      _plansError = null;
    });
    try {
      final plans = await DirectoryService.getPublishedPlans(card.id);
      if (mounted) setState(() => _plans = plans);
    } on AppError catch (e) {
      if (mounted) setState(() => _plansError = e.message);
    } finally {
      if (mounted) setState(() => _plansLoading = false);
    }
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _recipesLoading = true;
      _recipesError = null;
    });
    try {
      final recipes = await RecipeService.getPublicRecipesBy(card.id);
      if (mounted) setState(() => _recipes = recipes);
    } on AppError catch (e) {
      if (mounted) setState(() => _recipesError = e.message);
    } finally {
      if (mounted) setState(() => _recipesLoading = false);
    }
  }

  Future<void> _refresh() => Future.wait([_loadPlans(), _loadRecipes()]);

  Future<void> _startChat() async {
    setState(() => _starting = true);
    try {
      final id = await ChatService.start(card.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: id, otherName: card.displayName, linked: card.isMyNutritionist),
        ),
      );
    } on AppError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _openRecipe(Recipe r) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          card.displayName,
          style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: RefreshIndicator(
        color: primaryTeal,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _sectionTitle('Piani alimentari di base'),
            const SizedBox(height: 8),
            ..._buildPlans(),
            const SizedBox(height: 24),
            _sectionTitle('Ricette'),
            const SizedBox(height: 8),
            ..._buildRecipes(),
          ],
        ),
      ),
    );
  }

  // --- Intestazione --------------------------------------------------------

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.grey.shade200),
  );

  Widget _tag(String text, {Color color = primaryTeal, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(
            text,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
  );

  Widget _buildHeader() {
    final place = [if (card.city != null) card.city!, if (card.online) 'Online'].join(' · ');
    final s = card.socials;
    final links = <({String url, String label, IconData icon})>[
      if (s.instagram != null)
        (url: s.instagram!, label: socialLinkStyle(s.instagram!).label, icon: socialLinkStyle(s.instagram!).icon),
      if (s.tiktok != null)
        (url: s.tiktok!, label: socialLinkStyle(s.tiktok!).label, icon: socialLinkStyle(s.tiktok!).icon),
      if (s.youtube != null)
        (url: s.youtube!, label: socialLinkStyle(s.youtube!).label, icon: socialLinkStyle(s.youtube!).icon),
      if (s.website != null) (url: s.website!, label: 'Sito web', icon: Icons.language),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: primaryTeal.withValues(alpha: 0.12),
                child: Text(
                  card.displayName.isNotEmpty ? card.displayName.characters.first.toUpperCase() : '?',
                  style: const TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            card.displayName,
                            style: const TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Tooltip(
                          message: 'Professionista verificato',
                          child: Icon(Icons.verified, size: 20, color: primaryTeal),
                        ),
                      ],
                    ),
                    Text(card.professionLabel, style: const TextStyle(color: textSecondary)),
                    if (card.studioName != null)
                      Text(card.studioName!, style: const TextStyle(color: textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (card.headline != null) ...[
            const SizedBox(height: 12),
            Text(
              card.headline!,
              style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
            ),
          ],
          if (place.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 16, color: textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(place, style: const TextStyle(color: textSecondary)),
                ),
              ],
            ),
          ],
          if (card.isMyNutritionist || !card.acceptingPatients) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (card.isMyNutritionist) _tag('Il tuo nutrizionista', icon: Icons.check_circle),
                if (!card.acceptingPatients)
                  _tag('Non accetta nuovi pazienti', color: textSecondary, icon: Icons.block),
              ],
            ),
          ],
          if (card.bio != null) ...[
            const SizedBox(height: 12),
            Text(card.bio!, style: const TextStyle(color: textPrimary, height: 1.4)),
          ],
          if (card.specialties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final sp in card.specialties) _tag(specialtyLabels[sp] ?? sp)],
            ),
          ],
          if (links.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in links)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTeal,
                      side: BorderSide(color: Colors.grey.shade300),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => openExternalLink(context, l.url),
                    icon: Icon(l.icon, size: 18),
                    label: Text(l.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- Piani di base ---------------------------------------------------------

  Widget _sectionState({required bool loading, String? error, required VoidCallback retry, required String empty}) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: primaryTeal)),
      );
    }
    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration,
        child: Row(
          children: [
            Expanded(
              child: Text(error, style: const TextStyle(color: textSecondary)),
            ),
            TextButton(onPressed: retry, child: const Text('Riprova')),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Text(empty, style: const TextStyle(color: textSecondary)),
    );
  }

  List<Widget> _buildPlans() {
    if (_plansLoading || _plansError != null || _plans.isEmpty) {
      return [
        _sectionState(
          loading: _plansLoading,
          error: _plansError,
          retry: _loadPlans,
          empty: 'Nessun piano di base pubblicato.',
        ),
      ];
    }
    return [
      for (final p in _plans) ...[_buildPlanCard(p), const SizedBox(height: 12)],
    ];
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
    final hasMacros = p.proteinG != null || p.carbsG != null || p.fatG != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p.title,
                  style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (p.priceLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  p.priceLabel!,
                  style: const TextStyle(color: primaryTeal, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          if (p.description != null) ...[
            const SizedBox(height: 6),
            Text(p.description!, style: const TextStyle(color: textSecondary, height: 1.4)),
          ],
          if (p.kcal != null || hasMacros || p.durationWeeks != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (p.kcal != null)
                  Text(
                    '${p.kcal!.round()} kcal/giorno',
                    style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                  ),
                if (p.proteinG != null) _macro('P', p.proteinG!, colorP),
                if (p.carbsG != null) _macro('C', p.carbsG!, colorC),
                if (p.fatG != null) _macro('G', p.fatG!, colorG),
                if (p.durationWeeks != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 14, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        p.durationWeeks == 1 ? '1 settimana' : '${p.durationWeeks} settimane',
                        style: const TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tags) _tag(t)]),
          ],
        ],
      ),
    );
  }

  // --- Ricette ---------------------------------------------------------------

  List<Widget> _buildRecipes() {
    if (_recipesLoading || _recipesError != null || _recipes.isEmpty) {
      return [
        _sectionState(
          loading: _recipesLoading,
          error: _recipesError,
          retry: _loadRecipes,
          empty: 'Nessuna ricetta pubblicata.',
        ),
      ];
    }
    return [
      for (final r in _recipes) ...[_buildRecipeCard(r), const SizedBox(height: 10)],
    ];
  }

  Widget _buildRecipeCard(Recipe r) {
    final tags = [
      for (final t in r.restrictionTags) dietaryRestrictionLabels[t] ?? t,
      for (final g in r.goalTags) goalTagLabels[g] ?? g,
    ];
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openRecipe(r),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '${r.kcalPerServing.round()} kcal/porzione',
                        if (r.prepMinutes != null) '${r.prepMinutes} min',
                      ].join(' · '),
                      style: const TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tags.take(4)) _tag(t)]),
                    ],
                  ],
                ),
              ),
              if (r.socialUrl != null)
                IconButton(
                  tooltip: socialLinkStyle(r.socialUrl!).label,
                  icon: Icon(socialLinkStyle(r.socialUrl!).icon, color: primaryTeal),
                  onPressed: () => openExternalLink(context, r.socialUrl!),
                ),
              const Icon(Icons.chevron_right, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // --- Contatto ----------------------------------------------------------------

  Widget? _buildBottomBar() {
    if (_isMe) return null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_canWrite)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Al momento non accetta nuovi pazienti, quindi non è possibile scrivergli.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: !_canWrite || _starting ? null : _startChat,
                icon: _starting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.chat_bubble_outline),
                label: Text('Scrivi a ${card.displayName}', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
