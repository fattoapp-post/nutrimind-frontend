import 'app_error.dart';
import 'models.dart';
import 'supabase.dart';

/// Un piano macro con i suoi obiettivi per pasto e le istruzioni.
class MacroPlan {
  final String id;
  final String name;
  final String? notes;
  final DateTime? validFrom;

  /// Chi l'ha scritto: null quando il paziente si autogestisce.
  final String? nutritionistId;
  final Map<MealSlot, MealTarget> targets;

  const MacroPlan({
    required this.id,
    required this.name,
    this.notes,
    this.validFrom,
    this.nutritionistId,
    this.targets = const {},
  });

  bool get isSelfManaged => nutritionistId == null;

  double get kcal => targets.values.fold(0.0, (s, t) => s + t.kcal);
  double get proteinG => targets.values.fold(0.0, (s, t) => s + t.proteinG);
  double get carbsG => targets.values.fold(0.0, (s, t) => s + t.carbsG);
  double get fatG => targets.values.fold(0.0, (s, t) => s + t.fatG);
}

/// Piani macro: li scrive il professionista per i propri pazienti, oppure
/// il paziente per sé quando non è seguito da nessuno (autogestione).
class PlanService {
  /// Pasti su cui si distribuiscono gli obiettivi, nell'ordine della
  /// giornata. Lo spuntino serale si aggiunge solo se lo si compila.
  static const planSlots = [
    MealSlot.breakfast,
    MealSlot.morningSnack,
    MealSlot.lunch,
    MealSlot.afternoonSnack,
    MealSlot.dinner,
    MealSlot.eveningSnack,
  ];

  /// Ripartizione tipica della giornata. Serve solo come punto di
  /// partenza per "Distribuisci": ogni valore resta modificabile.
  static const defaultShares = <MealSlot, double>{
    MealSlot.breakfast: 0.20,
    MealSlot.morningSnack: 0.10,
    MealSlot.lunch: 0.35,
    MealSlot.afternoonSnack: 0.10,
    MealSlot.dinner: 0.25,
    MealSlot.eveningSnack: 0.0,
  };

  /// Il paziente può darsi obiettivi da solo? No se ha un professionista
  /// collegato: in quel caso il piano è suo e sovrascriverlo renderebbe
  /// l'aderenza un dato senza senso.
  static Future<bool> canSelfManage() {
    return withSessionRetry(() async {
      final value = await supabase.rpc('can_self_manage_plan');
      return value == true;
    });
  }

  /// Piano in corso. Senza [patientId] è il proprio.
  static Future<MacroPlan?> getCurrentPlan({String? patientId}) {
    return withSessionRetry(() async {
      final plans = await supabase.rpc(
        'get_current_macro_plan',
        params: {'p_patient_id': ?patientId},
      ) as List;
      if (plans.isEmpty) return null;
      final plan = Map<String, dynamic>.from(plans.first as Map);

      final rows = List<Map<String, dynamic>>.from(
        await supabase.from('macro_plan_targets').select().eq('plan_id', plan['id'] as String),
      );
      // Si tengono gli obiettivi validi tutti i giorni; quelli per un
      // giorno preciso li gestisce il diario, non l'editor.
      final targets = <MealSlot, MealTarget>{};
      for (final r in rows.where((r) => r['day_of_week'] == null)) {
        final slot = MealSlot.fromValue(r['meal_slot'] as String?);
        targets[slot] = MealTarget(
          proteinG: _num(r['protein_g']),
          carbsG: _num(r['carbs_g']),
          fatG: _num(r['fat_g']),
        );
      }

      return MacroPlan(
        id: plan['id'] as String,
        name: (plan['name'] as String?) ?? 'Piano',
        notes: (plan['notes'] as String?)?.trim().isEmpty ?? true ? null : (plan['notes'] as String).trim(),
        validFrom: DateTime.tryParse(plan['valid_from']?.toString() ?? ''),
        nutritionistId: plan['nutritionist_id'] as String?,
        targets: targets,
      );
    });
  }

  /// Crea un piano e chiude il precedente. Senza [patientId] vale per sé.
  static Future<String> savePlan({
    String? patientId,
    required String name,
    required Map<MealSlot, MealTarget> targets,
    String? notes,
    DateTime? validFrom,
  }) {
    return withSessionRetry(() async {
      final id = await supabase.rpc('start_macro_plan', params: {
        'p_patient_id': patientId ?? supabase.auth.currentUser!.id,
        'p_name': name,
        'p_valid_from': isoDate(validFrom ?? DateTime.now()),
        'p_notes': ?notes,
        'p_targets': [
          for (final e in targets.entries)
            if (!e.value.isEmpty)
              {
                'day_of_week': null,
                'meal_slot': e.key.value,
                'protein_g': e.value.proteinG,
                'carbs_g': e.value.carbsG,
                'fat_g': e.value.fatG,
              },
        ],
      });
      return id as String;
    });
  }

  /// Dalle calorie e dalla ripartizione dei macro ai grammi per pasto.
  /// [proteinPct] + [carbsPct] + [fatPct] devono dare 100.
  static Map<MealSlot, MealTarget> distribute({
    required double kcal,
    required double proteinPct,
    required double carbsPct,
    required double fatPct,
    Map<MealSlot, double>? shares,
  }) {
    final used = shares ?? defaultShares;
    final total = used.values.fold(0.0, (s, v) => s + v);
    if (total <= 0 || kcal <= 0) return const {};

    final dailyProtein = kcal * proteinPct / 100 / 4;
    final dailyCarbs = kcal * carbsPct / 100 / 4;
    final dailyFat = kcal * fatPct / 100 / 9;

    final out = <MealSlot, MealTarget>{};
    for (final e in used.entries) {
      if (e.value <= 0) continue;
      final share = e.value / total;
      out[e.key] = MealTarget(
        proteinG: (dailyProtein * share).roundToDouble(),
        carbsG: (dailyCarbs * share).roundToDouble(),
        fatG: (dailyFat * share).roundToDouble(),
      );
    }
    return out;
  }

  static double _num(dynamic v) => switch (v) {
        num n => n.toDouble(),
        String s => double.tryParse(s) ?? 0,
        _ => 0,
      };
}
