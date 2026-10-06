import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/food/favorites_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('--- Inizio avvio app ---');
  try {
    print('Sto contattando Supabase...');
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    ).timeout(const Duration(seconds: 10)); 
    print('Supabase connesso con successo!');
  } catch (e) {
    print('ERRORE CRITICO SUPABASE: $e');
  }
  
  print('Avvio interfaccia grafica...');
  runApp(const ProviderScope(child: NutriMindApp()));
}

class NutriMindApp extends StatelessWidget {
  const NutriMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriMind',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}