import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/community_models.dart';
import '../../core/recipe_service.dart';
import 'recipe_detail_screen.dart';
import 'recipe_editor_screen.dart';

/// Le ricette create dall'utente e, per il nutrizionista, quelle dei
/// pazienti da verificare. Con [embedded] è una tab dell'app nutrizionista.
class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key, this.showReviewQueue = false, this.embedded = false});

  final bool showReviewQueue;
  final bool embedded;

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color colorC = Color(0xFFF0A500);
  static const Color colorG = Color(0xFFEB5A0C);

  List<Recipe> _mine = [];
  bool _loadingMine = true;
  String? _mineError;

  List<RecipeToReview> _toReview = [];
  bool _loadingReview = false;
  String? _reviewError;

  @override
  void initState() {
    super.initState();
    _loadMine();
    if (widget.showReviewQueue) _loadReview();
  }

  Future<void> _loadMine() async {
    setState(() {
      _loadingMine = true;
      _mineError = null;
    });
    try {
      final recipes = await RecipeService.getMyRecipes();
      if (!mounted) return;
      setState(() {
        _mine = recipes;
        _loadingMine = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _mineError = e.message;
        _loadingMine = false;
      });
    }
  }

  Future<void> _loadReview() async {
    setState(() {
      _loadingReview = true;
      _reviewError = null;
    });
    try {
      final items = await RecipeService.getToReview();
      if (!mounted) return;
      setState(() {
        _toReview = items;
        _loadingReview = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewError = e.message;
        _loadingReview = false;
      });
    }
  }

  Future<void> _reloadAll() async {
    await Future.wait([_loadMine(), if (widget.showReviewQueue) _loadReview()]);
  }

  Future<void> _create() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const RecipeEditorScreen()));
    if (!mounted) return;
    if (saved == true) await _loadMine();
  }

  Future<void> _open(String recipeId) async {
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipeId)));
    if (!mounted) return;
    await _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton.extended(
      backgroundColor: primaryTeal,
      foregroundColor: Colors.white,
      onPressed: _create,
      icon: const Icon(Icons.add),
      label: const Text('Nuova ricetta'),
    );
    final appBarTitle = Text(widget.embedded ? 'Ricette' : 'Le mie ricette',
        style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold));
    final leading = widget.embedded
        ? null
        : IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: textPrimary),
            onPressed: () => Navigator.pop(context),
          );

    if (!widget.showReviewQueue) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          automaticallyImplyLeading: !widget.embedded,
          leading: leading,
          title: appBarTitle,
          centerTitle: true,
        ),
        floatingActionButton: fab,
        body: _buildMine(),
      );
    }

    final reviewCount = _loadingReview && _toReview.isEmpty ? '' : ' (${_toReview.length})';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          automaticallyImplyLeading: !widget.embedded,
          leading: leading,
          title: appBarTitle,
          centerTitle: true,
          bottom: TabBar(
            labelColor: primaryTeal,
            unselectedLabelColor: textSecondary,
            indicatorColor: primaryTeal,
            tabs: [
              const Tab(text: 'Le mie ricette'),
              Tab(text: 'Da verificare$reviewCount'),
            ],
          ),
        ),
        floatingActionButton: fab,
        body: TabBarView(children: [_buildMine(), _buildReview()]),
      ),
    );
  }

  Widget _buildMine() {
    if (_loadingMine && _mine.isEmpty) return const Center(child: CircularProgressIndicator(color: primaryTeal));
    if (_mineError != null && _mine.isEmpty) return _buildError(_mineError!, _loadMine);
    if (_mine.isEmpty) {
      return _buildEmpty(
        Icons.menu_book_outlined,
        'Non hai ancora creato ricette.\nCrea la tua prima ricetta con gli alimenti del catalogo.',
        action: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: primaryTeal),
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const Text('Nuova ricetta'),
        ),
        onRefresh: _loadMine,
      );
    }
    return RefreshIndicator(
      color: primaryTeal,
      onRefresh: _loadMine,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _mine.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildRecipeCard(_mine[i]),
      ),
    );
  }

  Widget _buildReview() {
    if (_loadingReview && _toReview.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: primaryTeal));
    }
    if (_reviewError != null && _toReview.isEmpty) return _buildError(_reviewError!, _loadReview);
    if (_toReview.isEmpty) {
      return _buildEmpty(
        Icons.fact_check_outlined,
        'Nessuna ricetta da verificare.\nQui compariranno le ricette che i tuoi pazienti ti inviano.',
        onRefresh: _loadReview,
      );
    }
    return RefreshIndicator(
      color: primaryTeal,
      onRefresh: _loadReview,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _toReview.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final r = _toReview[i];
          return _card(
            onTap: () => _open(r.id),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          r.authorName ?? 'Paziente',
                          '${r.kcalTotal.round()} kcal totali',
                          if (r.createdAt != null) _fmtDate(r.createdAt!),
                        ].join(' · '),
                        style: const TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: textSecondary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipeCard(Recipe r) {
    return _card(
      onTap: () => _open(r.id),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _statusChip(r),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${r.kcalPerServing.round()} kcal / porzione',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: textSecondary),
        ],
      ),
    );
  }

  Widget _statusChip(Recipe r) {
    final color = switch (r.status) {
      'approved' => primaryTeal,
      'pending_review' => colorC,
      'rejected' => colorG,
      _ => textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(r.statusLabel, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _card({required Widget child, VoidCallback? onTap}) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: child,
        ),
      );

  Widget _buildError(String message, Future<void> Function() retry) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: textSecondary)),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: primaryTeal),
                onPressed: retry,
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty(IconData icon, String text, {Widget? action, required Future<void> Function() onRefresh}) =>
      RefreshIndicator(
        color: primaryTeal,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 40),
            Icon(icon, size: 56, color: textSecondary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: textSecondary, fontSize: 15)),
            if (action != null) ...[
              const SizedBox(height: 20),
              Center(child: action),
            ],
          ],
        ),
      );

  static String _fmtDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }
}
