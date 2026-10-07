import 'package:flutter_test/flutter_test.dart';
import 'package:nutrimind/core/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// All'utente non devono mai arrivare messaggi SQL. Qui si verifica che
/// ogni errore che il database può restituire diventi una frase
/// comprensibile e uno stato HTTP sensato.
void main() {
  PostgrestException pg(String code, {String message = 'errore'}) =>
      PostgrestException(message: message, code: code);

  group('messageForStatus', () {
    test('ogni stato gestito ha un messaggio in italiano', () {
      expect(AppError.messageForStatus(401), 'Sessione scaduta. Accedi di nuovo.');
      expect(AppError.messageForStatus(403), 'Operazione non autorizzata.');
      expect(AppError.messageForStatus(404), 'Elemento non trovato.');
      expect(AppError.messageForStatus(429), 'Troppe richieste. Riprova tra poco.');
      expect(AppError.messageForStatus(501), 'Questa funzione non è ancora attiva sul server.');
      expect(AppError.messageForStatus(503), 'Servizio temporaneamente non disponibile.');
    });

    test('uno stato ignoto dà il messaggio generico', () {
      expect(AppError.messageForStatus(null), 'Si è verificato un errore. Riprova.');
      expect(AppError.messageForStatus(418), 'Si è verificato un errore. Riprova.');
    });
  });

  group('SQLSTATE -> stato HTTP', () {
    test('permesso negato dal database è un 403', () {
      expect(AppError.from(pg('42501')).status, 403);
    });

    test('riga non trovata è un 404', () {
      expect(AppError.from(pg('PGRST116')).status, 404);
    });

    test('token non valido è un 401', () {
      expect(AppError.from(pg('PGRST301')).status, 401);
    });

    test('funzione o tabella mancante è un 501: manca una migration', () {
      for (final code in ['42883', '42P01', 'PGRST202', 'PGRST205']) {
        expect(AppError.from(pg(code)).status, 501, reason: code);
      }
    });

    test('limite di frequenza del database è un 429', () {
      expect(AppError.from(pg('54000')).status, 429);
    });

    test('violazione di un vincolo è un 400, non un 500', () {
      for (final code in ['23514', '23505', '22023']) {
        expect(AppError.from(pg(code)).status, 400, reason: code);
      }
    });

    test('un SQLSTATE numerico non viene confuso con uno stato HTTP', () {
      // 22P02 e simili non sono stati HTTP: meglio nessuno stato che uno sbagliato.
      expect(AppError.from(pg('XX000')).status, isNull);
      expect(AppError.from(pg('23502')).status, isNull);
    });
  });

  group('Eccezioni sollevate dalle RPC', () {
    test('il nome dell\'eccezione diventa una frase per l\'utente', () {
      expect(AppError.from(pg('P0001', message: 'rate_limited')).message,
          'Stai inviando troppi messaggi. Riprova tra poco.');
      expect(AppError.from(pg('P0001', message: 'not_accepting_patients')).message,
          'Al momento questo professionista non accetta nuovi pazienti.');
      expect(AppError.from(pg('P0001', message: 'unusable_foods_in_meal')).message,
          'La ricetta contiene alimenti non più disponibili: sostituiscili.');
    });

    test('un\'eccezione sconosciuta non mostra il testo grezzo', () {
      final e = AppError.from(pg('P0001', message: 'relation "x" does not exist'));
      expect(e.message, 'Si è verificato un errore. Riprova.');
    });
  });

  group('Errori di autenticazione', () {
    test('credenziali sbagliate', () {
      final e = AppError.from(AuthException('Invalid login credentials', statusCode: '400'));
      expect(e.message, 'Email o password non validi.');
    });

    test('email già usata', () {
      final e = AppError.from(AuthException('User already registered', statusCode: '422'));
      expect(e.message, 'Email già registrata.');
    });

    test('sessione scaduta', () {
      final e = AppError.from(AuthException('bad jwt', statusCode: '401'));
      expect(e.status, 401);
      expect(e.message, 'Sessione scaduta. Accedi di nuovo.');
    });
  });

  group('Classificazione', () {
    test('riconosce gli errori passeggeri, su cui vale riprovare', () {
      expect(const AppError('x', status: 429).isTemporary, isTrue);
      expect(const AppError('x', status: 503).isTemporary, isTrue);
      expect(const AppError('x', status: 403).isTemporary, isFalse);
    });

    test('un AppError non viene riavvolto', () {
      const original = AppError('messaggio', status: 418);
      expect(AppError.from(original), same(original));
    });
  });
}
