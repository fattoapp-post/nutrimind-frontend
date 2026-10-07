import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_error.dart';
import 'models.dart';
import 'supabase.dart';

/// Accesso a catalogo, preferiti, diario e piano macro tramite Supabase.
/// Le RPC applicano i permessi lato DB (RLS / auth.uid()), quindi non si
/// passa mai l'id utente preso dalla UI.
class FoodService {
  // --- Catalogo ---------------------------------------------------------

  /// Catalogo locale. [filters] applica i vincoli sui valori per 100 g:
  /// con i soli filtri si può cercare anche senza testo.
  static Future<List<Food>> searchFoods(String query, {int limit = 20, NutrientFilters? filters}) {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('search_foods', params: {
        'p_query': query.trim().isEmpty ? null : query.trim(),
        'p_limit': limit,
        ...?filters?.toParams(),
      });
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

  /// Ricerca remota su Open Food Facts tramite Edge Function `search-off`.
  /// Da usare solo su richiesta esplicita, quando il catalogo locale non
  /// basta: OFF ha limiti di frequenza stretti.
  static Future<List<OffProduct>> searchOff(String query, {int limit = 10}) {
    return withSessionRetry(() async {
      final res = await supabase.functions.invoke('search-off', body: {'query': query, 'limit': limit});
      final results = ((res.data as Map?)?['results'] as List?) ?? const [];
      return results
          .map((r) => OffProduct.fromJson(Map<String, dynamic>.from(r as Map)))
          .where((p) => p.barcode != null && p.barcode!.isNotEmpty)
          .toList();
    });
  }

  static Future<List<FoodPortion>> getPortions(String foodId) {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_food_portions', params: {'p_food_id': foodId}) as List;
      return rows.map((r) => FoodPortion.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    });
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
    return withSessionRetry(() => _logMeal(food.id, slot, grams, date));
  }

  static Future<String> _logMeal(String foodId, MealSlot slot, double grams, DateTime date) async {
    final id = await supabase.rpc('log_meal', params: {
      'p_entry_date': isoDate(date),
      'p_meal_slot': slot.value,
      'p_grams': grams,
      'p_food_id': foodId,
    });
    return id as String;
  }

  /// Cambia i grammi di una voce. Non c'è una RPC di modifica: si registra
  /// la nuova voce (log_meal ricalcola i macro) e poi si elimina la vecchia,
  /// così in caso di errore non si perde nulla.
  static Future<void> updateEntryGrams(DiaryEntry entry, double grams, DateTime date) {
    final foodId = entry.foodId;
    if (foodId == null) throw const AppError('Questa voce non può essere modificata.');
    return withSessionRetry(() async {
      await _logMeal(foodId, entry.slot, grams, date);
      await supabase.rpc('delete_diary_entry', params: {'p_entry_id': entry.id});
    });
  }

  /// Copia in [to] le voci di [slot] registrate in [from]. Restituisce
  /// quante voci sono state copiate.
  static Future<int> copyMeal({required DateTime from, required DateTime to, required MealSlot slot}) async {
    final source = (await getDiaryEntries(from)).where((e) => e.slot == slot && e.foodId != null).toList();
    for (final e in source) {
      await withSessionRetry(() => _logMeal(e.foodId!, slot, e.grams, to));
    }
    return source.length;
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

  // --- Pasti personali --------------------------------------------------

  static Future<List<PersonalMeal>> getPersonalMeals() {
    return withSessionRetry(() async {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return <PersonalMeal>[];
      final List<Map<String, dynamic>> rows = await supabase
          .from('personal_meals')
          .select('id, name, default_slot, use_count')
          .eq('patient_id', uid)
          .order('use_count', ascending: false);
      return rows.map(PersonalMeal.fromJson).toList();
    });
  }

  /// Salva le voci di un pasto del diario come pasto personale riusabile.
  static Future<String> createPersonalMeal(String name, List<DiaryEntry> entries, {MealSlot? defaultSlot}) {
    return withSessionRetry(() async {
      final id = await supabase.rpc('create_personal_meal', params: {
        'p_name': name,
        'p_items': [
          for (final e in entries)
            if (e.foodId != null) {'food_id': e.foodId, 'grams': e.grams},
        ],
        'p_default_slot': ?defaultSlot?.value,
      });
      return id as String;
    });
  }

  static Future<void> deletePersonalMeal(String mealId) {
    // RLS: solo i propri pasti
    return withSessionRetry(() => supabase.from('personal_meals').delete().eq('id', mealId));
  }

  /// Registra tutte le voci del pasto personale. Restituisce quante voci
  /// sono state inserite.
  static Future<int> logPersonalMeal(String mealId, DateTime date, MealSlot slot) {
    return withSessionRetry(() async {
      final count = await supabase.rpc('log_personal_meal', params: {
        'p_meal_id': mealId,
        'p_date': isoDate(date),
        'p_slot': slot.value,
      });
      return (count as num?)?.toInt() ?? 0;
    });
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

      double n(dynamic v) => switch (v) {
            num x => x.toDouble(),
            String s => double.tryParse(s) ?? 0,
            _ => 0,
          };
      double sum(String key) => dayTargets.fold(0.0, (s, t) => s + n(t[key]));

      // Un pasto può avere più righe (per esempio uno spuntino diviso):
      // si sommano, così l'obiettivo del pasto è uno solo.
      final bySlot = <MealSlot, MealTarget>{};
      for (final t in dayTargets) {
        final slot = MealSlot.fromValue(t['meal_slot'] as String?);
        final before = bySlot[slot] ?? const MealTarget();
        bySlot[slot] = MealTarget(
          proteinG: before.proteinG + n(t['protein_g']),
          carbsG: before.carbsG + n(t['carbs_g']),
          fatG: before.fatG + n(t['fat_g']),
        );
      }
      return DailyTargets(
        // Le kcal si ricavano dai macro: `kcal_estimated` è lo stesso
        // calcolo fatto dal database, e sommare i due porterebbe a
        // numeri diversi fra giornata e singoli pasti.
        kcal: bySlot.values.fold(0.0, (s, t) => s + t.kcal),
        proteinG: sum('protein_g'),
        carbsG: sum('carbs_g'),
        fatG: sum('fat_g'),
        fromPlan: true,
        planName: plans.first['name'] as String?,
        targetsBySlot: bySlot,
      );
    });
  }

  /// Aderenza del paziente loggato (Edge Function `analyze-adherence`).
  static Future<AdherenceSummary> getMyAdherence(DateTime from, DateTime to) {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw const AppError('Sessione scaduta. Accedi di nuovo.', status: 401);
    return withSessionRetry(() async {
      final res = await supabase.functions.invoke('analyze-adherence', body: {
        'patient_id': uid,
        'from_date': isoDate(from),
        'to_date': isoDate(to),
      });
      return AdherenceSummary.fromJson(Map<String, dynamic>.from(res.data as Map));
    });
  }

  // --- Alimenti personali -------------------------------------------------

  /// Crea un alimento personale (RLS foods_insert_user: source 'user',
  /// non verificato). Valori per 100 g.
  static Future<Food> createUserFood({
    required String name,
    String? brand,
    String? barcode,
    required double kcal,
    required double proteinG,
    required double carbsG,
    required double fatG,
    double? servingG,
  }) {
    return withSessionRetry(() async {
      final row = await supabase
          .from('foods')
          .insert({
            'name': name,
            'brand': ?brand,
            'barcode': ?barcode,
            'kcal': kcal,
            'protein_g': proteinG,
            'carbs_g': carbsG,
            'fat_g': fatG,
            'serving_g': ?servingG,
            'source': 'user',
            'verification': 'unverified',
          })
          .select()
          .single();
      return Food.fromJson(row);
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
