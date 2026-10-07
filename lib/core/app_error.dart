import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Errore normalizzato da mostrare all'utente: mai SQL, stack trace o token.
class AppError implements Exception {
  final String message;
  final int? status;

  const AppError(this.message, {this.status});

  bool get isNotFound => status == 404;
  bool get isTemporary => status == 429 || (status != null && status! >= 502);

  static String messageForStatus(int? status) {
    if (status == 401) return 'Sessione scaduta. Accedi di nuovo.';
    if (status == 403) return 'Operazione non autorizzata.';
    if (status == 404) return 'Elemento non trovato.';
    if (status == 429) return 'Troppe richieste. Riprova tra poco.';
    if (status == 501) return 'Questa funzione non è ancora attiva sul server.';
    if (status != null && status >= 502) return 'Servizio temporaneamente non disponibile.';
    return 'Si è verificato un errore. Riprova.';
  }

  factory AppError.from(Object error) {
    if (error is AppError) return error;
    debugPrint('Errore: $error');

    if (error is AuthException) {
      final status = int.tryParse(error.statusCode ?? '');
      if (status == 400 || status == 422) {
        return AppError(_authMessage(error), status: status);
      }
      return AppError(messageForStatus(status), status: status);
    }
    if (error is PostgrestException) {
      final status = _statusForPostgrest(error);
      final known = _knownMessages[error.message.trim()];
      return AppError(known ?? messageForStatus(status), status: status);
    }
    if (error is FunctionException) {
      return AppError(messageForStatus(error.status), status: error.status);
    }
    return AppError(messageForStatus(null));
  }

  /// Codici Postgres/PostgREST -> stato HTTP equivalente. Solo i codici
  /// noti: un SQLSTATE come 23514 non è uno stato HTTP.
  static int? _statusForPostgrest(PostgrestException e) {
    switch (e.code) {
      case '42501':
        return 403;
      case 'P0002':
      case 'PGRST116':
        return 404;
      case '28000':
      case 'PGRST301':
      case 'PGRST302':
      case 'PGRST303':
        return 401;
      // Funzione o tabella non presente nello schema: migration mancante
      case 'PGRST202':
      case 'PGRST205':
      case '42883':
      case '42P01':
        return 501;
      case '54000':
        return 429;
      case '22023':
      case '22008':
      case '23514':
      case '23505':
      case '55000':
        return 400;
    }
    final code = int.tryParse(e.code ?? '');
    return (code != null && code >= 400 && code < 600) ? code : null;
  }

  /// Eccezioni sollevate dalle RPC (raise exception '...') -> messaggio utente.
  static const _knownMessages = {
    'forbidden': 'Operazione non autorizzata.',
    'not_found': 'Elemento non trovato.',
    'not_authenticated': 'Sessione scaduta. Accedi di nuovo.',
    'rate_limited': 'Stai inviando troppi messaggi. Riprova tra poco.',
    'nutritionist_not_verified': 'Serve la verifica professionale per questa operazione.',
    'meal_has_no_items': 'Aggiungi almeno un ingrediente alla ricetta.',
    'unusable_foods_in_meal': 'La ricetta contiene alimenti non più disponibili: sostituiscili.',
    'unverified_foods_in_meal': 'La ricetta contiene alimenti non ancora verificati.',
    'rejection_notes_required': 'Scrivi al paziente cosa modificare.',
    'invalid_state': 'La ricetta è già stata inviata o pubblicata.',
    'invalid_servings': 'Numero di porzioni non valido.',
    'invalid_visibility': 'Visibilità non valida.',
    'cannot_review_own_meal': 'Non puoi verificare una tua ricetta.',
    'empty_message': 'Il messaggio è vuoto.',
    'not_accepting_patients': 'Al momento questo professionista non accetta nuovi pazienti.',
    'too_many_open_invitations': 'Hai troppi inviti ancora aperti.',
    'food_not_available': 'Alimento non più disponibile.',
    'food_not_found': 'Alimento non trovato.',
    'invalid_entry_date': 'Data non valida.',
  };

  static String _authMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login')) return 'Email o password non validi.';
    if (msg.contains('already registered')) return 'Email già registrata.';
    if (msg.contains('password')) return 'Password non valida (minimo 8 caratteri).';
    return 'Dati non validi. Controlla e riprova.';
  }

  @override
  String toString() => message;
}

/// Esegue [action]; dopo un 401 rinnova la sessione una volta e riprova.
Future<T> withSessionRetry<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    if (AppError.from(e).status != 401) throw AppError.from(e);
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {
      throw const AppError('Sessione scaduta. Accedi di nuovo.', status: 401);
    }
    try {
      return await action();
    } catch (e) {
      throw AppError.from(e);
    }
  }
}
