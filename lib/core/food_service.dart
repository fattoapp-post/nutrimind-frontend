import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_error.dart';
import 'models.dart';
import 'supabase.dart';

/// Accesso a catalogo, preferiti, diario e piano macro tramite Supabase.
/// Le RPC applicano i permessi lato DB (RLS / auth.uid()), quindi non si
/// passa mai l'id utente preso dalla UI.
class FoodService {
  // --- Catalogo ---------------------------------------------------------

  static Future<List<Food>> searchFoods(String query, {int limit = 20}) {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('search_foods', params: {'p_query': query, 'p_limit': limit});
      return _foods(rows);
    });
  }

  static Future<Food?> getFood(String id) {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_food', params: {'p_id': id});
      final foods = _foods(rows);
      return foods.isEmpty ? null : foods.first;
    });
  }

  /// Flusso barcode: catalogo locale, poi import da Open Food Facts tramite
  /// Edge Function, poi rilettura del record locale. Mai OFF dal client.
  /// Restituisce null se il prodotto non esiste.
  static Future<Food?> getFoodByBarcode(String barcode) async {
    final local = await withSessionRetry(() async {
      final rows = await supabase.rpc('get_food_by_barcode', params: {'p_barcode': barcode});
      return _foods(rows);
    });
    if (local.isNotEmpty) return local.first;

    final String? foodId;
    try {
      final res = await withSessionRetry(
        () => supabase.functions.invoke('import-off-barcode', body: {'barcode': barcode}),
      );
      foodId = (res.data as Map?)?['food_id'] as String?;
    } on AppError catch (e) {
      // La funzione risponde 400 anche quando il prodotto non è su OFF.
      if (e.status == 400 || e.isNotFound) return null;
      rethrow;
    }
    if (foodId == null) return null;
    return getFood(foodId);
  }

  // --- Preferiti --------------------------------------------------------

  static Future<List<FavoriteFood>> getFavorites() {
    return withSessionRetry(() async {
      final rows = List<Map<String, dynamic>>.from(await supabase.rpc('get_favorite_foods') as List);
      if (rows.isEmpty) return <FavoriteFood>[];

      final foods = await _foodsById(rows.map((r) => r['food_id'] as String).toSet());
      return [
        for (final r in rows)
          if (foods[r['food_id']] != null)
            FavoriteFood(
              food: foods[r['food_id']]!,
              defaultGrams: (r['default_grams'] as num?)?.toDouble() ?? 100,
              defaultSlot: r['default_slot'] == null ? null : MealSlot.fromValue(r['default_slot'] as String),
              useCount: (r['use_count'] as num?)?.toInt() ?? 0,
              lastUsedAt: DateTime.tryParse(r['last_used_at']?.toString() ?? ''),
            ),
      ];
    });
  }

  static Future<bool> isFavorite(String foodId) {
    return withSessionRetry(() async {
      final row = await supabase.from('favorite_foods').select('id').eq('food_id', foodId).maybeSingle();
      return row != null;
    });
  }

  static Future<void> setFavorite(String foodId, bool favorite, {double? defaultGrams}) {
    return withSessionRetry(() async {
      if (favorite) {
        await supabase.rpc('add_favorite_food', params: {
          'p_food_id': foodId,
          'p_default_grams': ?defaultGrams,
        });
      } else {
        // RLS: l'utente può cancellare solo i propri preferiti.
        await supabase.from('favorite_foods').delete().eq('food_id', foodId);
      }
    });
  }

  // --- Diario -----------------------------------------------------------

  static Future<String> logMeal({
    required Food food,
    required MealSlot slot,
    required double grams,
    required DateTime date,
  }) {
    return withSessionRetry(() async {
      final id = await supabase.rpc('log_meal', params: {
        'p_entry_date': isoDate(date),
        'p_meal_slot': slot.value,
        'p_grams': grams,
        'p_food_id': food.id,
      });
      return id as String;
    });
  }

  static Future<List<DiaryEntry>> getDiaryEntries(DateTime date) {
    return withSessionRetry(() async {
      final rows = List<Map<String, dynamic>>.from(
        await supabase.rpc('get_diary_entries', params: {'p_date': isoDate(date)}) as List,
      );
      final foodIds = rows.map((r) => r['food_id'] as String?).whereType<String>().toSet();
      final foods = foodIds.isEmpty ? <String, Food>{} : await _foodsById(foodIds);
      return [
        for (final r in rows) DiaryEntry.fromJson(r, foodName: foods[r['food_id']]?.name),
      ];
    });
  }

  static Future<void> deleteDiaryEntry(String entryId) {
    return withSessionRetry(() => supabase.rpc('delete_diary_entry', params: {'p_entry_id': entryId}));
  }

  // --- Piano macro ------------------------------------------------------

  /// Somma dei target del piano corrente per il giorno di [date].
  /// I target con `day_of_week` nullo valgono per tutti i giorni.
  static Future<DailyTargets> getDailyTargets(DateTime date) {
    return withSessionRetry(() async {
      final plans = List<Map<String, dynamic>>.from(await supabase.rpc('get_current_macro_plan') as List);
      if (plans.isEmpty) return DailyTargets.fallback;

      final targets = List<Map<String, dynamic>>.from(
        await supabase.from('macro_plan_targets').select().eq('plan_id', plans.first['id'] as String),
      );
      var dayTargets = targets.where((t) => t['day_of_week'] == date.weekday).toList();
      if (dayTargets.isEmpty) dayTargets = targets.where((t) => t['day_of_week'] == null).toList();
      if (dayTargets.isEmpty) return DailyTargets.fallback;

      double sum(String key) => dayTargets.fold(0.0, (s, t) => s + ((t[key] as num?)?.toDouble() ?? 0));
      final p = sum('protein_g'), c = sum('carbs_g'), f = sum('fat_g');
      final hasKcal = dayTargets.every((t) => t['kcal_estimated'] != null);
      return DailyTargets(
        kcal: hasKcal ? sum('kcal_estimated') : p * 4 + c * 4 + f * 9,
        proteinG: p,
        carbsG: c,
        fatG: f,
        fromPlan: true,
      );
    });
  }

  // --- Helper -----------------------------------------------------------

  static List<Food> _foods(dynamic rows) =>
      List<Map<String, dynamic>>.from(rows as List).map(Food.fromJson).toList();

  static Future<Map<String, Food>> _foodsById(Set<String> ids) async {
    final List<Map<String, dynamic>> rows = await supabase.from('foods').select().inFilter('id', ids.toList());
    return {for (final r in rows) r['id'] as String: Food.fromJson(r)};
  }
}

/// Nome visualizzato dal profilo; fallback sulla parte locale dell'email.
Future<String> loadDisplayName() async {
  final user = supabase.auth.currentUser;
  if (user == null) return 'Utente';
  try {
    final row = await supabase.from('profiles').select('display_name').eq('id', user.id).maybeSingle();
    final name = (row?['display_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
  } on PostgrestException {
    // profilo non leggibile: usa il fallback
  }
  final local = user.email?.split('@').first ?? '';
  return local.isEmpty ? 'Utente' : '${local[0].toUpperCase()}${local.substring(1)}';
}
