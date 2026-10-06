import 'package:supabase_flutter/supabase_flutter.dart';

/// Unico punto di accesso al client Supabase.
SupabaseClient get supabase => Supabase.instance.client;
