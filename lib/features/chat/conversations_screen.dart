import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/chat_service.dart';
import '../../core/community_models.dart';
import '../directory/find_nutritionist_screen.dart';
import 'chat_screen.dart';

/// Elenco delle conversazioni. Per il nutrizionista può essere una tab
/// dell'app ([embedded]).
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key, this.embedded = false, this.iAmNutritionist = false});

  final bool embedded;
  final bool iAmNutritionist;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  List<Conversation> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await ChatService.getConversations();
      if (mounted) setState(() => _items = items);
    } on AppError catch (e) {
      if (!mounted) return;
      if (silent && _items.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Conversation c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: c.id,
          otherName: c.otherName,
          iAmNutritionist: widget.iAmNutritionist,
          linked: c.linked,
        ),
      ),
    );
    if (!mounted) return;
    _load(silent: true);
  }

  Future<void> _findNutritionist() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FindNutritionistScreen()));
    if (!mounted) return;
    _load(silent: true);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// oggi HH:mm / ieri / dd/MM
  static String _relativeTime(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(local);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '${_two(local.hour)}:${_two(local.minute)}';
    if (diff == 1) return 'ieri';
    return '${_two(local.day)}/${_two(local.month)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        title: const Text(
          'Messaggi',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!widget.iAmNutritionist)
            IconButton(
              tooltip: 'Trova un nutrizionista',
              icon: const Icon(Icons.person_search_outlined, color: primaryTeal),
              onPressed: _findNutritionist,
            ),
        ],
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
              onRefresh: () => _load(silent: true),
              child: _items.isEmpty ? _buildEmpty() : _buildList(),
            ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.chat_bubble_outline, size: 56, color: textSecondary),
        const SizedBox(height: 16),
        Text(
          widget.iAmNutritionist
              ? 'I pazienti che ti scrivono compariranno qui.'
              : 'Nessuna conversazione. Trova un nutrizionista e scrivigli.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: textSecondary, fontSize: 15),
        ),
        if (!widget.iAmNutritionist) ...[
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: primaryTeal),
              onPressed: _findNutritionist,
              icon: const Icon(Icons.person_search_outlined),
              label: const Text('Trova un nutrizionista'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) => Divider(height: 1, indent: 72, color: Colors.grey.shade200),
      itemBuilder: (context, i) {
        final c = _items[i];
        final unread = c.unreadCount > 0;
        return ListTile(
          onTap: () => _open(c),
          leading: CircleAvatar(
            backgroundColor: primaryTeal.withValues(alpha: 0.12),
            child: Text(
              c.otherName.isNotEmpty ? c.otherName.characters.first.toUpperCase() : '?',
              style: const TextStyle(color: primaryTeal, fontWeight: FontWeight.bold),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  c.otherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textPrimary, fontWeight: unread ? FontWeight.bold : FontWeight.w600),
                ),
              ),
              if (c.linked) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Collegato', style: TextStyle(color: primaryTeal, fontSize: 11)),
                ),
              ],
            ],
          ),
          subtitle: Text(
            c.lastMessage ?? 'Nessun messaggio',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: unread ? textPrimary : textSecondary),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _relativeTime(c.lastMessageAt),
                style: TextStyle(color: unread ? primaryTeal : textSecondary, fontSize: 12),
              ),
              if (unread) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: primaryTeal, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
