import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_error.dart';
import 'models.dart';
import 'supabase.dart';

/// Notifiche in-app e commenti del nutrizionista lato paziente.
class NotificationService {
  static Future<List<AppNotification>> getUnread() {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_unread_notifications') as List;
      return rows.map((r) => AppNotification.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    });
  }

  static Future<void> markRead(String notificationId) {
    return withSessionRetry(
      () => supabase.rpc('mark_notification_read', params: {'p_notification_id': notificationId}),
    );
  }

  /// Avvisa a ogni nuova notifica dell'utente corrente. Restituisce il
  /// canale da chiudere con [unsubscribe]. Richiede che la tabella sia
  /// nella publication `supabase_realtime`; se non lo è, non arriva nulla
  /// e l'app continua a funzionare con il caricamento manuale.
  static RealtimeChannel? subscribe(void Function() onNew) {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    return supabase
        .channel('notifications:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (_) => onNew(),
        )
        .subscribe();
  }

  static Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel != null) await supabase.removeChannel(channel);
  }

  // --- Commenti del nutrizionista (vista paziente) -------------------------

  static Future<List<NutritionistComment>> getMyComments(DateTime from, DateTime to) {
    return withSessionRetry(() async {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return <NutritionistComment>[];
      final rows = await supabase.rpc('get_nutritionist_comments', params: {
        'p_patient_id': uid,
        'p_from': isoDate(from),
        'p_to': isoDate(to),
      }) as List;
      return rows.map((r) => NutritionistComment.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    });
  }

  static Future<void> markCommentRead(String commentId) {
    return withSessionRetry(() => supabase.rpc('mark_comment_read', params: {'p_comment_id': commentId}));
  }
}
