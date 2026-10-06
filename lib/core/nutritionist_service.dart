import 'app_error.dart';
import 'models.dart';
import 'supabase.dart';

/// Operazioni del portale nutrizionista. I permessi (collegamento attivo,
/// consenso del paziente, verifica professionale) sono applicati dalle RPC.
class NutritionistService {
  static Future<List<PatientOverview>> getMyPatients() {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_my_patients') as List;
      final patients = rows.map((r) => PatientOverview.fromJson(Map<String, dynamic>.from(r as Map))).toList();
      patients.sort((a, b) => b.attentionScore.compareTo(a.attentionScore));
      return patients;
    });
  }

  /// Righe di `adherence_day`, una per giorno. Richiede il consenso
  /// `adherence` del paziente.
  static Future<List<Map<String, dynamic>>> getPatientAdherence(
    String patientId,
    DateTime from,
    DateTime to, {
    double tolerance = 0.10,
  }) {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_patient_adherence', params: {
        'p_patient_id': patientId,
        'p_from': isoDate(from),
        'p_to': isoDate(to),
        'p_tolerance': tolerance,
      }) as List;
      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    });
  }

  /// Richiede il consenso `diary` del paziente.
  static Future<List<DiaryMealWithComments>> getDiaryWithComments(String patientId, DateTime from, DateTime to) {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_diary_with_comments', params: {
        'p_patient_id': patientId,
        'p_from': isoDate(from),
        'p_to': isoDate(to),
      }) as List;
      return rows.map((r) => DiaryMealWithComments.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    });
  }

  static Future<String> createComment({
    required String patientId,
    required DateTime date,
    required String body,
    MealSlot? slot,
  }) {
    return withSessionRetry(() async {
      final id = await supabase.rpc('create_nutritionist_comment', params: {
        'p_patient_id': patientId,
        'p_comment_date': isoDate(date),
        'p_body': body,
        'p_meal_slot': ?slot?.value,
      });
      return id as String;
    });
  }

  /// Crea un nuovo piano (chiude quello precedente). [targetsBySlot] vale
  /// per tutti i giorni della settimana (`day_of_week` nullo).
  static Future<String> startMacroPlan({
    required String patientId,
    required String name,
    required DateTime validFrom,
    required Map<MealSlot, ({double protein, double carbs, double fat})> targetsBySlot,
  }) {
    return withSessionRetry(() async {
      final id = await supabase.rpc('start_macro_plan', params: {
        'p_patient_id': patientId,
        'p_name': name,
        'p_valid_from': isoDate(validFrom),
        'p_targets': [
          for (final e in targetsBySlot.entries)
            {
              'day_of_week': null,
              'meal_slot': e.key.value,
              'protein_g': e.value.protein,
              'carbs_g': e.value.carbs,
              'fat_g': e.value.fat,
            },
        ],
      });
      return id as String;
    });
  }

  /// Solo nutrizionisti verificati o admin. Valori per 100 g.
  static Future<String> createFood({
    required String name,
    required double kcal,
    required double proteinG,
    required double carbsG,
    required double fatG,
    String? brand,
    String? barcode,
  }) {
    return withSessionRetry(() async {
      final id = await supabase.rpc('create_food', params: {
        'p_name': name,
        'p_kcal': kcal,
        'p_protein_g': proteinG,
        'p_carbs_g': carbsG,
        'p_fat_g': fatG,
        'p_brand': ?brand,
        'p_barcode': ?barcode,
      });
      return id as String;
    });
  }

  /// Solo nutrizionisti verificati o admin.
  static Future<String> createFoodPortion(String foodId, String label, double grams) {
    return withSessionRetry(() async {
      final id = await supabase.rpc('create_food_portion', params: {
        'p_food_id': foodId,
        'p_label': label,
        'p_grams': grams,
      });
      return id as String;
    });
  }

  /// Restrizioni e preferenze del paziente (policy
  /// patient_settings_select_nutritionist: serve il consenso `profile`).
  /// Null se non condivise.
  static Future<PatientSettings?> getPatientSettings(String patientId) {
    return withSessionRetry(() async {
      final row = await supabase.from('patient_settings').select().eq('user_id', patientId).maybeSingle();
      return row == null ? null : PatientSettings.fromJson(row);
    });
  }

  /// Piano macro in corso del paziente con i target per pasto.
  static Future<({String name, DateTime? validFrom, List<Map<String, dynamic>> targets})?> getCurrentPlan(
    String patientId,
  ) {
    return withSessionRetry(() async {
      final plans = await supabase.rpc('get_current_macro_plan', params: {'p_patient_id': patientId}) as List;
      if (plans.isEmpty) return null;
      final plan = Map<String, dynamic>.from(plans.first as Map);
      final List<Map<String, dynamic>> targets =
          await supabase.from('macro_plan_targets').select().eq('plan_id', plan['id'] as String);
      return (
        name: (plan['name'] as String?) ?? 'Piano',
        validFrom: DateTime.tryParse(plan['valid_from']?.toString() ?? ''),
        targets: targets,
      );
    });
  }

  /// Edge Function `analyze-adherence`: riepilogo del periodo.
  static Future<AdherenceSummary> analyzeAdherence(String patientId, DateTime from, DateTime to) {
    return withSessionRetry(() async {
      final res = await supabase.functions.invoke('analyze-adherence', body: {
        'patient_id': patientId,
        'from_date': isoDate(from),
        'to_date': isoDate(to),
      });
      return AdherenceSummary.fromJson(Map<String, dynamic>.from(res.data as Map));
    });
  }
}
