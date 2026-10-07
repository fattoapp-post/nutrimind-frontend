import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_error.dart';
import 'community_models.dart';
import 'supabase.dart';

/// Chat paziente-nutrizionista. Le scritture passano dalle RPC
/// (`send_message`, `send_invitation_message`), che validano i membri,
/// limitano lo spam e creano la notifica per il destinatario.
class ChatService {
  static Future<List<Conversation>> getConversations() {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_my_conversations') as List;
      return rows.map((r) => Conversation.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    });
  }

  /// Totale messaggi non letti (badge).
  static Future<int> unreadCount() async {
    final conversations = await getConversations();
    return conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
  }

  /// Apre (o riprende) la conversazione con un nutrizionista in vetrina o
  /// collegato; per il nutrizionista, con un proprio paziente.
  static Future<String> start(String otherUserId) {
    return withSessionRetry(() async {
      final id = await supabase.rpc('start_conversation', params: {'p_other': otherUserId});
      return id as String;
    });
  }

  static Future<List<ChatMessage>> getMessages(String conversationId, {int limit = 200}) {
    return withSessionRetry(() async {
      final List<Map<String, dynamic>> rows = await supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(ChatMessage.fromJson).toList().reversed.toList();
    });
  }

  static Future<void> send(String conversationId, String body) => withSessionRetry(
        () => supabase.rpc('send_message', params: {'p_conversation': conversationId, 'p_body': body}),
      );

  /// Condivide una ricetta in chat (il destinatario la apre con un tocco).
  static Future<void> shareRecipe(String conversationId, Recipe recipe) => withSessionRetry(
        () => supabase.rpc('send_message', params: {
          'p_conversation': conversationId,
          'p_body': 'Ti consiglio la ricetta "${recipe.title}"',
          'p_kind': 'recipe',
          'p_payload': {'recipe_id': recipe.id},
        }),
      );

  /// Solo nutrizionista: invia un codice invito che il paziente usa con un tocco.
  static Future<void> sendInvitation(String conversationId) => withSessionRetry(
        () => supabase.rpc('send_invitation_message', params: {'p_conversation': conversationId}),
      );

  static Future<void> markRead(String conversationId) => withSessionRetry(
        () => supabase.rpc('mark_conversation_read', params: {'p_conversation': conversationId}),
      );

  /// Nuovi messaggi in tempo reale per una conversazione.
  static RealtimeChannel subscribe(String conversationId, void Function(ChatMessage message) onMessage) {
    return supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: conversationId),
          callback: (payload) => onMessage(ChatMessage.fromJson(payload.newRecord)),
        )
        .subscribe();
  }

  static Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel != null) await supabase.removeChannel(channel);
  }
}
