double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _numOrNull(dynamic v) => (v as num?)?.toDouble();

/// Valori dell'enum `public.meal_slot`.
enum MealSlot {
  breakfast('breakfast', 'Colazione', '08:00'),
  morningSnack('morning_snack', 'Spuntino', '11:00'),
  lunch('lunch', 'Pranzo', '13:00'),
  afternoonSnack('afternoon_snack', 'Merenda', '16:30'),
  dinner('dinner', 'Cena', '20:00'),
  eveningSnack('evening_snack', 'Spuntino serale', '22:00');

  final String value;
  final String label;
  final String time;
  const MealSlot(this.value, this.label, this.time);

  static MealSlot fromValue(String? value) =>
      MealSlot.values.firstWhere((s) => s.value == value, orElse: () => MealSlot.morningSnack);

  /// Slot suggerito in base all'ora corrente.
  static MealSlot forNow() {
    final h = DateTime.now().hour;
    if (h < 10) return breakfast;
    if (h < 12) return morningSnack;
    if (h < 15) return lunch;
    if (h < 18) return afternoonSnack;
    if (h < 22) return dinner;
    return eveningSnack;
  }
}

/// Riga di `public.foods`. I valori nutrizionali sono per 100 g.
class Food {
  final String id;
  final String name;
  final String? brand;
  final String? barcode;
  final String source;
  final String verification;
  final int trustLevel;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? servingG;
  final String? servingLabel;

  const Food({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    required this.source,
    required this.verification,
    required this.trustLevel,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.servingG,
    this.servingLabel,
  });

  bool get isVerified => verification == 'verified';

  String get subtitle => [brand, servingLabel].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  factory Food.fromJson(Map<String, dynamic> json) => Food(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        brand: json['brand'] as String?,
        barcode: json['barcode'] as String?,
        source: (json['source'] as String?) ?? 'user',
        verification: (json['verification'] as String?) ?? 'unverified',
        trustLevel: (json['trust_level'] as num?)?.toInt() ?? 0,
        kcal: _num(json['kcal']),
        proteinG: _num(json['protein_g']),
        carbsG: _num(json['carbs_g']),
        fatG: _num(json['fat_g']),
        servingG: _numOrNull(json['serving_g']),
        servingLabel: json['serving_label'] as String?,
      );
}

/// Riga di `public.favorite_foods` con l'alimento collegato.
class FavoriteFood {
  final Food food;
  final double defaultGrams;
  final MealSlot? defaultSlot;
  final int useCount;
  final DateTime? lastUsedAt;

  const FavoriteFood({
    required this.food,
    required this.defaultGrams,
    this.defaultSlot,
    required this.useCount,
    this.lastUsedAt,
  });
}

/// Riga di `public.diary_entries`. I macro sono già calcolati sui grammi.
class DiaryEntry {
  final String id;
  final String? foodId;
  final String name;
  final MealSlot slot;
  final double grams;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const DiaryEntry({
    required this.id,
    this.foodId,
    required this.name,
    required this.slot,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json, {String? foodName}) => DiaryEntry(
        id: json['id'] as String,
        foodId: json['food_id'] as String?,
        name: foodName ?? (json['custom_name'] as String?) ?? 'Alimento',
        slot: MealSlot.fromValue(json['meal_slot'] as String?),
        grams: _num(json['grams']),
        kcal: _num(json['kcal']),
        proteinG: _num(json['protein_g']),
        carbsG: _num(json['carbs_g']),
        fatG: _num(json['fat_g']),
      );
}

/// Obiettivi giornalieri derivati dal piano macro corrente.
class DailyTargets {
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final bool fromPlan;

  const DailyTargets({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fromPlan,
  });

  /// Valori di fallback quando il paziente non ha un piano attivo.
  static const fallback = DailyTargets(kcal: 2000, proteinG: 140, carbsG: 220, fatG: 65, fromPlan: false);
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
