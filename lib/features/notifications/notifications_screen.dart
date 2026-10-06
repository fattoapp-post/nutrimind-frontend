import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/models.dart';
import '../../core/notification_service.dart';

/// Notifiche non lette. Toccandone una viene segnata come letta.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color primaryTeal = Color(0xFF127B6D);

  List<AppNotification> _items = [];
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
      final items = await NotificationService.getUnread();
      if (mounted) setState(() => _items = items);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    setState(() => _items = _items.where((i) => i.id != n.id).toList());
    try {
      await NotificationService.markRead(n.id);
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      _load();
    }
  }

  Future<void> _markAllRead() async {
    final items = _items;
    setState(() => _items = []);
    try {
      await Future.wait(items.map((n) => NotificationService.markRead(n.id)));
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      _load();
    }
  }

  IconData _icon(String type) => switch (type) {
        'new_comment' || 'nutritionist_comment' => Icons.chat_bubble_outline,
        'plan_updated' => Icons.assignment_outlined,
        'link_event' => Icons.link,
        'logging_reminder' => Icons.alarm,
        'meal_review' => Icons.rate_review_outlined,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(onPressed: _markAllRead, child: const Text('Segna tutte lette', style: TextStyle(color: primaryTeal))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryTeal))
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('Riprova')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          Center(child: Text('Nessuna notifica da leggere.')),
                        ])
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final n = _items[i];
                            return ListTile(
                              leading: Icon(_icon(n.type), color: primaryTeal),
                              title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(n.body),
                              trailing: IconButton(
                                tooltip: 'Segna come letta',
                                icon: const Icon(Icons.done),
                                onPressed: () => _markRead(n),
                              ),
                              onTap: () => _markRead(n),
                            );
                          },
                        ),
                ),
    );
  }
}
