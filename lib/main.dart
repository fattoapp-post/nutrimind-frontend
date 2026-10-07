import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/push_service.dart';
import 'core/theme.dart';
import 'features/auth/auth_gate.dart';

/// Albero di accessibilità sempre acceso. Sul web Flutter lo costruisce solo
/// dopo che l'utente ha premuto il pulsante nascosto "Enable accessibility":
/// con questo flag lo si ha subito, come serve ai test automatici del browser.
/// Si attiva con `--dart-define=ENABLE_SEMANTICS=true`, mai in produzione:
/// mantenere l'albero aggiornato ha un costo.
const _enableSemantics = bool.fromEnvironment('ENABLE_SEMANTICS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_enableSemantics) SemanticsBinding.instance.ensureSemantics();

  AppConfig.validate();
  await themeController.load();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  await PushService.init();

  runApp(const ProviderScope(child: NutriMindApp()));
}

class NutriMindApp extends StatelessWidget {
  const NutriMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Al cambio di tema si ricostruisce tutto l'albero: è così che le
    // schermate rileggono la tavolozza (vedi core/theme.dart).
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) => MaterialApp(
        title: 'NutriMind',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        home: const AuthGate(),
      ),
    );
  }
}
