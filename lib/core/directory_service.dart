import 'app_error.dart';
import 'community_models.dart';
import 'supabase.dart';

/// Vetrina dei nutrizionisti e piani alimentari di base.
class DirectoryService {
  /// Nutrizionisti verificati con profilo pubblico (`search_nutritionists`).
  static Future<List<NutritionistCard>> search({String? query, String? specialty, String? restriction, bool? online}) {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('search_nutritionists', params: {
        if (query != null && query.trim().isNotEmpty) 'p_query': query.trim(),
        'p_specialty': ?specialty,
        'p_restriction': ?restriction,
        'p_online': ?online,
      }) as List;
      return rows.map((r) => NutritionistCard.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    });
  }

  /// Piani di base pubblicati da un nutrizionista.
  static Future<List<PlanTemplate>> getPublishedPlans(String nutritionistId) {
    return withSessionRetry(() async {
      final List<Map<String, dynamic>> rows = await supabase
          .from('nutritionist_plan_templates')
          .select()
          .eq('nutritionist_id', nutritionistId)
          .eq('is_published', true)
          .order('created_at', ascending: false);
      return rows.map(PlanTemplate.fromJson).toList();
    });
  }

  // --- Lato nutrizionista: gestione dei propri piani di base -------------

  static Future<List<PlanTemplate>> getMyPlans() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return Future.value(const []);
    return withSessionRetry(() async {
      final List<Map<String, dynamic>> rows = await supabase
          .from('nutritionist_plan_templates')
          .select()
          .eq('nutritionist_id', uid)
          .order('created_at', ascending: false);
      return rows.map(PlanTemplate.fromJson).toList();
    });
  }

  static Future<void> savePlan(PlanTemplate plan) {
    return withSessionRetry(() async {
      if (plan.id == null) {
        await supabase.from('nutritionist_plan_templates').insert(plan.toJson());
      } else {
        await supabase.from('nutritionist_plan_templates').update(plan.toJson()).eq('id', plan.id!);
      }
    });
  }

  static Future<void> deletePlan(String id) =>
      withSessionRetry(() => supabase.from('nutritionist_plan_templates').delete().eq('id', id));
}
