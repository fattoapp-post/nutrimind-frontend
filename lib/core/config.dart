/// Configurazione letta a build-time con `--dart-define-from-file`.
///
/// Solo URL e chiave publishable/anon possono stare nel frontend.
/// Mai usare la secret/service_role key nell'app.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL e SUPABASE_ANON_KEY mancanti. '
        'Avvia con: flutter run --dart-define-from-file=env/dev.json',
      );
    }
    if (supabaseAnonKey.startsWith('sb_secret_')) {
      throw StateError('La secret key non può essere usata nel frontend.');
    }
  }
}
