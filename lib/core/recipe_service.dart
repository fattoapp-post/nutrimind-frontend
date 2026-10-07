import 'app_error.dart';
import 'community_models.dart';
import 'models.dart';
import 'supabase.dart';

/// Ricette (tabella `suggested_meals`). Flusso:
/// - paziente: bozza -> `submit_meal_for_review` -> il suo nutrizionista
///   approva o rifiuta con `review_meal`;
/// - nutrizionista verificato: bozza -> `publish_own_meal` (per tutti o
///   solo per i suoi pazienti), senza revisione.
/// Visibilità e permessi sono applicati da RLS e RPC (migration 016).
class RecipeService {
  static const _detailSelect = '*, suggested_meal_items(id, grams, position, note, foods(*))';

  /// Ricette per l'aggiunta al diario: prima quelle del mio nutrizionista.
  static Future<List<Recipe>> getRecipesForMe({MealSlot? slot, List<String> restrictions = const [], String? query}) {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_recipes_for_me', params: {
        'p_slot': ?slot?.value,
        'p_restrictions': restrictions,
        if (query != null && query.trim().isNotEmpty) 'p_query': query.trim(),
      }) as List;
      return rows.map((r) => Recipe.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    });
  }

  /// Ricette pubbliche di un nutrizionista (pagina vetrina).
  static Future<List<Recipe>> getPublicRecipesBy(String authorId) {
    return withSessionRetry(() async {
      final List<Map<String, dynamic>> rows = await supabase
          .from('suggested_meals')
          .select()
          .eq('proposed_by', authorId)
          .eq('status', 'approved')
          .order('published_at', ascending: false);
      return rows.map(Recipe.fromJson).toList();
    });
  }

  /// Le ricette create dall'utente, in qualsiasi stato.
  static Future<List<Recipe>> getMyRecipes() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return Future.value(const []);
    return withSessionRetry(() async {
      final List<Map<String, dynamic>> rows = await supabase
          .from('suggested_meals')
          .select()
          .eq('proposed_by', uid)
          .order('updated_at', ascending: false);
      return rows.map(Recipe.fromJson).toList();
    });
  }

  static Future<Recipe> getRecipe(String id) {
    return withSessionRetry(() async {
      final row = Map<String, dynamic>.from(
        await supabase.from('suggested_meals').select(_detailSelect).eq('id', id).single(),
      );
      // L'autore arriva da una RPC: profiles non è leggibile per autori non collegati
      final author = await supabase.rpc('get_recipe_author', params: {'p_meal_id': id}) as List;
      if (author.isNotEmpty) {
        final a = Map<String, dynamic>.from(author.first as Map);
        row['author_name'] = a['author_name'];
        row['from_my_nutritionist'] = a['from_my_nutritionist'];
      }
      return Recipe.fromJson(row);
    });
  }

  /// Crea o aggiorna una bozza con i suoi ingredienti. Restituisce l'id.
  static Future<String> saveDraft({
    String? id,
    required String title,
    String? description,
    String? instructions,
    required List<MealSlot> slots,
    required int servings,
    required List<String> restrictionTags,
    required List<String> goalTags,
    String? socialUrl,
    int? prepMinutes,
    String visibility = 'public',
    required List<({String foodId, double grams})> ingredients,
  }) {
    // Un'unica RPC transazionale: ricetta e ingredienti si salvano insieme
    // o per niente (prima, un errore a metà lasciava la bozza vuota)
    return withSessionRetry(() async {
      final mealId = await supabase.rpc('save_meal_draft', params: {
        'p_meal_id': id,
        'p_data': {
          'title': title,
          'description': description,
          'instructions': instructions,
          'meal_slots': slots.map((s) => s.value).toList(),
          'servings': servings,
          'restriction_tags': restrictionTags,
          'goal_tags': goalTags,
          'social_url': socialUrl,
          'prep_minutes': prepMinutes,
          'visibility': visibility,
        },
        'p_items': [
          for (final i in ingredients) {'food_id': i.foodId, 'grams': i.grams},
        ],
      });
      return mealId as String;
    });
  }

  static Future<void> deleteDraft(String id) =>
      withSessionRetry(() => supabase.from('suggested_meals').delete().eq('id', id));

  /// Paziente: invia la bozza al proprio nutrizionista per la verifica.
  static Future<void> submitForReview(String id) =>
      withSessionRetry(() => supabase.rpc('submit_meal_for_review', params: {'p_meal_id': id}));

  /// Paziente: ritira una ricetta in revisione (torna bozza).
  static Future<void> withdraw(String id) =>
      withSessionRetry(() => supabase.rpc('withdraw_meal', params: {'p_meal_id': id}));

  /// Nutrizionista verificato: pubblica direttamente la propria ricetta.
  static Future<void> publishOwn(String id, {required bool onlyMyPatients}) => withSessionRetry(
        () => supabase.rpc('publish_own_meal', params: {
          'p_meal_id': id,
          'p_visibility': onlyMyPatients ? 'patients' : 'public',
        }),
      );

  static Future<void> unpublishOwn(String id) =>
      withSessionRetry(() => supabase.rpc('unpublish_own_meal', params: {'p_meal_id': id}));

  /// Nutrizionista: ricette dei pazienti da verificare.
  static Future<List<RecipeToReview>> getToReview() {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_meals_to_review') as List;
      return rows.map((r) => RecipeToReview.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    });
  }

  /// Nutrizionista: approva o rifiuta (le note sono obbligatorie se rifiuta).
  static Future<void> review(String id, {required bool approve, String? notes}) => withSessionRetry(
        () => supabase.rpc('review_meal', params: {'p_meal_id': id, 'p_approve': approve, 'p_notes': ?notes}),
      );

  /// Registra la ricetta nel diario per il numero di porzioni indicato.
  static Future<int> logToDiary(String id, {required DateTime date, required MealSlot slot, double servings = 1}) {
    return withSessionRetry(() async {
      final count = await supabase.rpc('log_suggested_meal', params: {
        'p_meal_id': id,
        'p_date': isoDate(date),
        'p_slot': slot.value,
        'p_servings': servings,
      });
      return (count as num?)?.toInt() ?? 0;
    });
  }
}

/// Consigli mirati: una ricetta o un alimento che il professionista
/// indica a un singolo paziente (migration 023).
class SuggestionService {
  /// Senza [patientId] sono i consigli ricevuti da chi chiama.
  static Future<List<PatientSuggestion>> list({String? patientId}) {
    return withSessionRetry(() async {
      final rows = await supabase.rpc(
        'get_patient_suggestions',
        params: {'p_patient_id': ?patientId},
      ) as List;
      return rows
          .map((r) => PatientSuggestion.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    });
  }

  /// Una delle due fra [mealId] e [foodId], non entrambe.
  static Future<String> add({
    required String patientId,
    String? mealId,
    String? foodId,
    String? note,
  }) {
    return withSessionRetry(() async {
      final id = await supabase.rpc('suggest_to_patient', params: {
        'p_patient_id': patientId,
        'p_meal_id': ?mealId,
        'p_food_id': ?foodId,
        'p_note': ?note,
      });
      return id as String;
    });
  }

  static Future<void> remove(String id) {
    return withSessionRetry(() => supabase.rpc('remove_patient_suggestion', params: {'p_id': id}));
  }
}
