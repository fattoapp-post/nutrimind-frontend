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
      return AppError(messageForStatus(status), status: status);
    }
    if (error is FunctionException) {
      return AppError(messageForStatus(error.status), status: error.status);
    }
    return AppError(messageForStatus(null));
  }

  static int? _statusForPostgrest(PostgrestException e) {
    switch (e.code) {
      case '42501':
        return 403;
      case 'P0002':
      case 'PGRST116':
        return 404;
      case 'PGRST301':
      case 'PGRST302':
        return 401;
    }
    return int.tryParse(e.code ?? '');
  }

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
