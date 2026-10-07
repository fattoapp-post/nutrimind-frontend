import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/chat_service.dart';
import '../../core/community_models.dart';
import '../../core/models.dart';
import '../../core/recipe_service.dart';
import '../../core/supabase.dart';
import '../recipes/recipe_detail_screen.dart';

/// Conversazione paziente-nutrizionista con aggiornamenti in tempo reale.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherName,
    this.iAmNutritionist = false,
    this.linked = false,
  });

  final String conversationId;
  final String otherName;
  final bool iAmNutritionist;
  final bool linked;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<ChatMessage> _messages = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  String? _error;
  bool _sending = false;
  bool _showPrivacy = true;
  late bool _linked = widget.linked;
  final Set<String> _redeeming = {};

  String? get _myId => supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = ChatService.subscribe(widget.conversationId, _onMessage);
  }

  @override
  void dispose() {
    ChatService.unsubscribe(_channel);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await ChatService.getMessages(widget.conversationId);
      if (!mounted) return;
      setState(() => _messages = _merge(_messages, messages));
      _markRead();
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Unisce due elenchi senza duplicati, in ordine cronologico.
  List<ChatMessage> _merge(List<ChatMessage> a, List<ChatMessage> b) {
    final byId = <String, ChatMessage>{for (final m in a) m.id: m, for (final m in b) m.id: m};
    return byId.values.toList()..sort((x, y) => x.createdAt.compareTo(y.createdAt));
  }

  void _onMessage(ChatMessage m) {
    if (!mounted) return;
    if (_messages.any((e) => e.id == m.id)) return;
    setState(() => _messages = _merge(_messages, [m]));
    _scrollToBottom();
    if (m.senderId != _myId) _markRead();
  }

  Future<void> _markRead() async {
    try {
      await ChatService.markRead(widget.conversationId);
    } on AppError {
      // Non bloccante: il badge si aggiorna al prossimo caricamento
    }
  }

  void _scrollToBottom() {
    // La lista è invertita: il fondo è l'offset 0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatService.send(widget.conversationId, text);
      if (!mounted) return;
      _input.clear();
      await _refreshAfterSend();
    } on AppError catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Ricarica dopo un invio, nel caso il realtime arrivi in ritardo.
  Future<void> _refreshAfterSend() async {
    try {
      final messages = await ChatService.getMessages(widget.conversationId);
      if (!mounted) return;
      setState(() => _messages = _merge(_messages, messages));
      _scrollToBottom();
    } on AppError {
      // Il messaggio è stato inviato; arriverà comunque via realtime
    }
  }

  // --- Azioni del nutrizionista -------------------------------------------

  Future<void> _sendInvitation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invia invito'),
        content: Text(
          'Invierai a ${widget.otherName} un invito a collegarsi con te. '
          'Potrà scegliere quali dati condividere.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryTeal),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Invia'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ChatService.sendInvitation(widget.conversationId);
      if (!mounted) return;
      _snack('Invito inviato');
      await _refreshAfterSend();
    } on AppError catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _shareRecipe() async {
    final recipe = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _RecipePickerSheet(),
    );
    if (recipe == null || !mounted) return;
    try {
      await ChatService.shareRecipe(widget.conversationId, recipe);
      if (!mounted) return;
      await _refreshAfterSend();
    } on AppError catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  // --- Azioni del paziente ------------------------------------------------

  Future<void> _redeem(ChatMessage m) async {
    final code = m.inviteCode;
    if (code == null) return;
    final scopes = await showDialog<Set<ConsentScope>>(
      context: context,
      builder: (_) => _ConsentDialog(nutritionistName: widget.otherName),
    );
    if (scopes == null || !mounted) return;
    setState(() => _redeeming.add(m.id));
    try {
      await AccountService.redeemInvitation(code, scopes);
      if (!mounted) return;
      setState(() => _linked = true);
      _snack('Ora sei collegato al tuo nutrizionista');
    } on AppError catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _redeeming.remove(m.id));
    }
  }

  void _openRecipe(String id) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)));
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          widget.otherName,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.iAmNutritionist && !_linked)
            IconButton(
              tooltip: 'Invia invito',
              icon: Icon(Icons.person_add, color: primaryTeal),
              onPressed: _sendInvitation,
            ),
          if (widget.iAmNutritionist)
            IconButton(
              tooltip: 'Condividi ricetta',
              icon: Icon(Icons.menu_book, color: primaryTeal),
              onPressed: _shareRecipe,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_showPrivacy) _buildPrivacyNote(),
          Expanded(child: _buildBody()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: primaryTeal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryTeal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: primaryTeal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'I messaggi sono visibili solo a te e a ${widget.otherName}. '
              'Non condividere dati sanitari sensibili non necessari.',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Chiudi',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 18, color: textSecondary),
            onPressed: () => setState(() => _showPrivacy = false),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _messages.isEmpty) {
      return Center(child: CircularProgressIndicator(color: primaryTeal));
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: textSecondary)),
            TextButton(onPressed: _load, child: const Text('Riprova')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Nessun messaggio. Scrivi a ${widget.otherName} per iniziare.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }
    final reversed = _messages.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: reversed.length,
      itemBuilder: (context, i) => _buildMessage(reversed[i]),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _time(DateTime t) {
    final local = t.toLocal();
    final hm = '${_two(local.hour)}:${_two(local.minute)}';
    if (DateUtils.isSameDay(local, DateTime.now())) return hm;
    return '${_two(local.day)}/${_two(local.month)} $hm';
  }

  Widget _buildMessage(ChatMessage m) {
    final mine = m.senderId == _myId;
    final Widget content = switch (m.kind) {
      'invite' => _buildInviteCard(m, mine),
      'recipe' => _buildRecipeCard(m, mine),
      _ => _buildTextBubble(m, mine),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: content,
          ),
          const SizedBox(height: 2),
          Text(_time(m.createdAt), style: TextStyle(color: textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  BoxDecoration _bubbleDecoration(bool mine) => BoxDecoration(
    color: mine ? primaryTeal : cardColor,
    borderRadius: BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    ),
    border: mine ? null : Border.all(color: borderColor),
  );

  Widget _buildTextBubble(ChatMessage m, bool mine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _bubbleDecoration(mine),
      child: SelectableText(m.body, style: TextStyle(color: mine ? Colors.white : textPrimary, fontSize: 15)),
    );
  }

  Widget _cardShell({required IconData icon, required String title, required String body, Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryTeal, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[const SizedBox(height: 6), Text(body, style: TextStyle(color: textSecondary))],
          if (action != null) ...[const SizedBox(height: 10), action],
        ],
      ),
    );
  }

  Widget _buildInviteCard(ChatMessage m, bool mine) {
    Widget? action;
    if (!widget.iAmNutritionist && !mine) {
      if (_linked) {
        action = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: primaryTeal, size: 18),
            SizedBox(width: 6),
            Text(
              'Collegato',
              style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w600),
            ),
          ],
        );
      } else {
        final busy = _redeeming.contains(m.id);
        action = FilledButton(
          style: FilledButton.styleFrom(backgroundColor: primaryTeal),
          onPressed: busy || m.inviteCode == null ? null : () => _redeem(m),
          child: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Collegati'),
        );
      }
    }
    return _cardShell(
      icon: Icons.link,
      title: 'Invito a collegarti',
      body: mine ? 'Hai invitato ${widget.otherName} a collegarsi con te.' : m.body,
      action: action,
    );
  }

  Widget _buildRecipeCard(ChatMessage m, bool mine) {
    final id = m.recipeId;
    return _cardShell(
      icon: Icons.menu_book,
      title: 'Ricetta condivisa',
      body: m.body,
      action: id == null
          ? null
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryTeal,
                side: BorderSide(color: primaryTeal),
              ),
              onPressed: () => _openRecipe(id),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Apri ricetta'),
            ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                // readOnly invece di enabled: la tastiera resta aperta durante l'invio
                readOnly: _sending,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Scrivi un messaggio',
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: bgColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: primaryTeal),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'Invia',
              style: IconButton.styleFrom(backgroundColor: primaryTeal),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scelta dei dati da condividere quando il paziente accetta un invito.
class _ConsentDialog extends StatefulWidget {
  const _ConsentDialog({required this.nutritionistName});

  final String nutritionistName;

  @override
  State<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<_ConsentDialog> {

  final Set<ConsentScope> _scopes = {ConsentScope.adherence, ConsentScope.diary};

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return AlertDialog(
      title: const Text('Collegati al nutrizionista'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scegli cosa può vedere ${widget.nutritionistName}. Puoi cambiare idea in qualsiasi momento dal profilo.',
              style: TextStyle(color: textSecondary),
            ),
            const SizedBox(height: 8),
            for (final s in ConsentScope.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: primaryTeal,
                value: _scopes.contains(s),
                title: Text(s.label),
                onChanged: (v) => setState(() => v == true ? _scopes.add(s) : _scopes.remove(s)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: primaryTeal),
          onPressed: () => Navigator.pop(context, Set<ConsentScope>.of(_scopes)),
          child: const Text('Collegati'),
        ),
      ],
    );
  }
}

/// Elenco delle proprie ricette pubblicate da condividere in chat.
class _RecipePickerSheet extends StatefulWidget {
  const _RecipePickerSheet();

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {

  List<Recipe> _recipes = [];
  bool _loading = true;
  String? _error;

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
      final all = await RecipeService.getMyRecipes();
      if (mounted) setState(() => _recipes = all.where((r) => r.isApproved).toList());
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    final Widget body;
    if (_loading) {
      body = Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: primaryTeal)),
      );
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: textSecondary)),
            TextButton(onPressed: _load, child: const Text('Riprova')),
          ],
        ),
      );
    } else if (_recipes.isEmpty) {
      body = Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Non hai ancora ricette pubblicate da condividere.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary),
        ),
      );
    } else {
      body = Flexible(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _recipes.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: borderColor),
          itemBuilder: (context, i) {
            final r = _recipes[i];
            return ListTile(
              leading: Icon(Icons.restaurant_menu, color: primaryTeal),
              title: Text(
                r.title,
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${r.kcalPerServing.round()} kcal/porzione · ${r.statusLabel}',
                style: TextStyle(color: textSecondary),
              ),
              onTap: () => Navigator.pop(context, r),
            );
          },
        ),
      );
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Condividi ricetta',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }
}
