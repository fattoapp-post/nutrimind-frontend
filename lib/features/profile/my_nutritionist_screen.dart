import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/chat_service.dart';
import '../../core/community_models.dart';
import '../../core/links.dart';
import '../../core/models.dart';
import '../chat/chat_screen.dart';
import '../directory/find_nutritionist_screen.dart';
import 'profile_widgets.dart';

/// Paziente: il nutrizionista collegato, i consensi condivisi e come
/// collegarsi (vetrina o codice invito).
class MyNutritionistScreen extends StatefulWidget {
  const MyNutritionistScreen({super.key});

  @override
  State<MyNutritionistScreen> createState() => _MyNutritionistScreenState();
}

class _MyNutritionistScreenState extends State<MyNutritionistScreen> {
  final _code = TextEditingController();
  Set<ConsentScope> _redeemScopes = {ConsentScope.adherence, ConsentScope.diary};
  List<PatientLink> _links = [];
  final Map<String, ({String name, NutritionistDetails? details})> _info = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final links = await AccountService.getMyLinks();
      for (final l in links) {
        _info[l.nutritionistId] = await AccountService.getLinkedNutritionist(l.nutritionistId);
      }
      if (mounted) setState(() => _links = links);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    final ok = await runWithFeedback(context, action, success: success);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _load();
  }

  Future<void> _openChat(PatientLink link) async {
    setState(() => _busy = true);
    try {
      final id = await ChatService.start(link.nutritionistId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id, otherName: _info[link.nutritionistId]?.name ?? 'Nutrizionista', linked: true)),
      );
    } on AppError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRevoke(PatientLink link) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Interrompere il collegamento?'),
        content: const Text('Il nutrizionista non potrà più vedere i tuoi dati né assegnarti piani.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Scollega')),
        ],
      ),
    );
    if (ok == true) await _act(() => AccountService.revokeLink(link.id), 'Collegamento interrotto.');
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return SettingsPage(
      title: 'Il mio nutrizionista',
      busy: _loading || _busy,
      children: [
        if (_error != null)
          SectionCard(children: [Text(_error!), TextButton(onPressed: _load, child: const Text('Riprova'))]),
        if (!_loading && _links.isEmpty) ..._buildNotLinked(),
        for (final link in _links) ..._buildLinked(link),
      ],
    );
  }

  List<Widget> _buildLinked(PatientLink link) {
    final info = _info[link.nutritionistId];
    final details = info?.details;
    return [
      SectionCard(
        children: [
          Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: ProfilePalette.tealSoft,
              child: Text((info?.name ?? 'N')[0].toUpperCase(),
                  style: TextStyle(color: ProfilePalette.teal, fontWeight: FontWeight.bold, fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info?.name ?? 'Il tuo nutrizionista',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ProfilePalette.textPrimary)),
                Text(
                  [professionLabels[details?.profession] ?? 'Nutrizionista', if (details?.studioName != null) details!.studioName!].join(' · '),
                  style: TextStyle(color: ProfilePalette.textSecondary),
                ),
              ]),
            ),
          ]),
          if (details?.headline != null) ...[
            const SizedBox(height: 12),
            Text(details!.headline!, style: TextStyle(color: ProfilePalette.textPrimary)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _busy ? null : () => _openChat(link),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Scrivi'),
            ),
            for (final url in [details?.instagramUrl, details?.tiktokUrl, details?.youtubeUrl, details?.websiteUrl].whereType<String>())
              OutlinedButton.icon(
                onPressed: () => openExternalLink(context, url),
                icon: Icon(socialLinkStyle(url).icon),
                label: Text(socialLinkStyle(url).label == 'Link' ? 'Sito' : socialLinkStyle(url).label),
              ),
          ]),
        ],
      ),
      SectionCard(
        title: 'Cosa condividi',
        subtitle: 'Puoi cambiare i consensi in qualsiasi momento. Revocarli non cancella i tuoi dati.',
        children: [
          for (final scope in ConsentScope.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(scope.label),
              subtitle: Text(switch (scope) {
                ConsentScope.adherence => 'Quanto segui il piano, senza il dettaglio dei pasti',
                ConsentScope.diary => 'Cosa mangi, pasto per pasto',
                ConsentScope.profile => 'Le tue restrizioni e scelte alimentari',
              }),
              value: link.activeScopes.contains(scope),
              activeThumbColor: ProfilePalette.teal,
              onChanged: _busy
                  ? null
                  : (on) => _act(
                        () => on ? AccountService.grantConsent(link.id, scope) : AccountService.revokeConsent(link.id, scope),
                        on ? 'Consenso concesso.' : 'Consenso revocato.',
                      ),
            ),
        ],
      ),
      Center(
        child: TextButton.icon(
          onPressed: _busy ? null : () => _confirmRevoke(link),
          icon: const Icon(Icons.link_off, color: Colors.red),
          label: const Text('Interrompi il collegamento', style: TextStyle(color: Colors.red)),
        ),
      ),
    ];
  }

  List<Widget> _buildNotLinked() {
    return [
      SectionCard(
        title: 'Trova il tuo nutrizionista',
        subtitle: 'Sfoglia professionisti verificati, guarda le loro ricette e i piani proposti, poi scrivigli direttamente.',
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FindNutritionistScreen()))
                .then((_) => _load()),
            icon: const Icon(Icons.search),
            label: const Text('Cerca un nutrizionista'),
          ),
        ],
      ),
      SectionCard(
        title: 'Hai un codice invito?',
        subtitle: 'Te lo dà il nutrizionista, anche in chat.',
        children: [
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Codice invito'),
          ),
          const SizedBox(height: 12),
          Text('Cosa condividi', style: TextStyle(color: ProfilePalette.textSecondary)),
          for (final scope in ConsentScope.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(scope.label),
              value: _redeemScopes.contains(scope),
              activeColor: ProfilePalette.teal,
              onChanged: (on) => setState(() {
                _redeemScopes = {..._redeemScopes};
                on == true ? _redeemScopes.add(scope) : _redeemScopes.remove(scope);
              }),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy || _code.text.trim().isEmpty
                  ? null
                  : () => _act(() async {
                        await AccountService.redeemInvitation(_code.text, _redeemScopes);
                        _code.clear();
                      }, 'Collegamento creato.'),
              child: const Text('Collegati'),
            ),
          ),
        ],
      ),
    ];
  }
}
