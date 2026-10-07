import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/community_models.dart';
import '../../core/directory_service.dart';
import '../../core/models.dart';
import 'nutritionist_public_screen.dart';

/// Vetrina dei nutrizionisti verificati con profilo pubblico.
class FindNutritionistScreen extends StatefulWidget {
  const FindNutritionistScreen({super.key});

  @override
  State<FindNutritionistScreen> createState() => _FindNutritionistScreenState();
}

class _FindNutritionistScreenState extends State<FindNutritionistScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  final _searchController = TextEditingController();
  Timer? _debounce;

  String? _specialty;
  String? _restriction;
  bool _onlineOnly = false;

  List<NutritionistCard> _items = [];
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _load);
  }

  Future<void> _load() async {
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await DirectoryService.search(
        query: _searchController.text,
        specialty: _specialty,
        restriction: _restriction,
        online: _onlineOnly ? true : null,
      );
      if (mounted && request == _requestId) setState(() => _items = items);
    } on AppError catch (e) {
      if (mounted && request == _requestId) setState(() => _error = e.message);
    } finally {
      if (mounted && request == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _open(NutritionistCard card) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NutritionistPublicScreen(card: card)));
  }

  bool get _hasFilters =>
      _specialty != null || _restriction != null || _onlineOnly || _searchController.text.trim().isNotEmpty;

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _specialty = null;
      _restriction = null;
      _onlineOnly = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          'Trova un nutrizionista',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                _debounce?.cancel();
                _load();
              },
              decoration: InputDecoration(
                hintText: 'Nome, studio, città…',
                prefixIcon: const Icon(Icons.search, color: textSecondary),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: primaryTeal),
                ),
              ),
            ),
          ),
          _buildFilters(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              FilterChip(
                label: const Text('Online'),
                avatar: Icon(Icons.videocam_outlined, size: 18, color: _onlineOnly ? Colors.white : primaryTeal),
                selected: _onlineOnly,
                showCheckmark: false,
                selectedColor: primaryTeal,
                labelStyle: TextStyle(color: _onlineOnly ? Colors.white : textPrimary),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade200),
                onSelected: (v) {
                  setState(() => _onlineOnly = v);
                  _load();
                },
              ),
              const SizedBox(width: 8),
              for (final e in specialtyLabels.entries) ...[
                _choice(e.value, _specialty == e.key, (v) {
                  setState(() => _specialty = v ? e.key : null);
                  _load();
                }),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('Propone ricette', style: TextStyle(color: textSecondary, fontSize: 12)),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final e in dietaryRestrictionLabels.entries) ...[
                _choice(e.value, _restriction == e.key, (v) {
                  setState(() => _restriction = v ? e.key : null);
                  _load();
                }),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _choice(String label, bool selected, ValueChanged<bool> onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: primaryTeal,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? primaryTeal : Colors.grey.shade200),
      labelStyle: TextStyle(color: selected ? Colors.white : textPrimary),
      onSelected: onSelected,
    );
  }

  Widget _buildResults() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: primaryTeal));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: textSecondary)),
            TextButton(onPressed: _load, child: const Text('Riprova')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: primaryTeal,
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(32),
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.verified_outlined, size: 56, color: textSecondary),
                const SizedBox(height: 16),
                Text(
                  _hasFilters
                      ? 'Nessun nutrizionista corrisponde ai filtri scelti.'
                      : 'Nessun nutrizionista disponibile.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Qui compaiono solo professionisti con abilitazione verificata '
                  'che hanno scelto di rendere pubblico il proprio profilo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary),
                ),
                if (_hasFilters) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Rimuovi i filtri', style: TextStyle(color: primaryTeal)),
                    ),
                  ),
                ],
              ],
            )
          : Stack(
              children: [
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _buildCard(_items[i]),
                ),
                if (_loading)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(color: primaryTeal, minHeight: 2),
                  ),
              ],
            ),
    );
  }

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

  Widget _buildCard(NutritionistCard c) {
    final place = [if (c.city != null) c.city!, if (c.online) 'Online'].join(' · ');
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(c),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: primaryTeal.withValues(alpha: 0.12),
                    child: Text(
                      c.displayName.isNotEmpty ? c.displayName.characters.first.toUpperCase() : '?',
                      style: const TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Tooltip(
                              message: 'Professionista verificato',
                              child: Icon(Icons.verified, size: 18, color: primaryTeal),
                            ),
                          ],
                        ),
                        Text(c.professionLabel, style: const TextStyle(color: textSecondary)),
                        if (place.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 14, color: textSecondary),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    place,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: textSecondary, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (c.headline != null) ...[
                const SizedBox(height: 10),
                Text(
                  c.headline!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textPrimary),
                ),
              ],
              if (c.specialties.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final s in c.specialties.take(3)) _tag(specialtyLabels[s] ?? s)],
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${c.recipesCount} ricette · ${c.plansCount} piani',
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  if (c.isMyNutritionist) _tag('Il tuo nutrizionista', icon: Icons.check_circle),
                  if (!c.acceptingPatients) _tag('Non accetta nuovi pazienti', color: textSecondary, icon: Icons.block),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
