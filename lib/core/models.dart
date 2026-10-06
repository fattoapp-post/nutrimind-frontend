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

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

/// Valori dell'enum `public.user_role`.
enum UserRole {
  patient,
  nutritionist,
  admin;

  static UserRole fromValue(String? v) =>
      UserRole.values.firstWhere((r) => r.name == v, orElse: () => UserRole.patient);
}

/// Valori dell'enum `public.consent_scope`.
enum ConsentScope {
  adherence('Aderenza al piano'),
  diary('Diario alimentare'),
  profile('Restrizioni alimentari');

  final String label;
  const ConsentScope(this.label);

  static ConsentScope? fromValue(String? v) {
    for (final s in ConsentScope.values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

/// Riga di `public.profiles`. L'email sta in auth.users, non qui.
class Profile {
  final String id;
  final UserRole role;
  final String displayName;
  final String locale;
  final bool professionalVerified;

  const Profile({
    required this.id,
    required this.role,
    required this.displayName,
    required this.locale,
    required this.professionalVerified,
  });

  bool get isNutritionist => role == UserRole.nutritionist || role == UserRole.admin;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        role: UserRole.fromValue(json['role'] as String?),
        displayName: (json['display_name'] as String?) ?? '',
        locale: (json['locale'] as String?) ?? 'it',
        professionalVerified: (json['professional_verified'] as bool?) ?? false,
      );
}

/// Valori ammessi per `patient_settings.dietary_restrictions`.
const dietaryRestrictionLabels = {
  'vegetarian': 'Vegetariano',
  'vegan': 'Vegano',
  'gluten_free': 'Senza glutine',
  'lactose_free': 'Senza lattosio',
  'nut_free': 'Senza frutta a guscio',
  'halal': 'Halal',
  'kosher': 'Kosher',
  'no_pork': 'No maiale',
  'no_fish': 'No pesce',
};

/// Riga di `public.patient_settings`.
class PatientSettings {
  final List<String> dietaryRestrictions;
  final String timezone;
  final bool remindersEnabled;
  final int reminderAfterHours;

  const PatientSettings({
    required this.dietaryRestrictions,
    required this.timezone,
    required this.remindersEnabled,
    required this.reminderAfterHours,
  });

  factory PatientSettings.fromJson(Map<String, dynamic> json) => PatientSettings(
        dietaryRestrictions: List<String>.from((json['dietary_restrictions'] as List?) ?? const []),
        timezone: (json['timezone'] as String?) ?? 'Europe/Rome',
        remindersEnabled: (json['reminders_enabled'] as bool?) ?? true,
        reminderAfterHours: (json['reminder_after_hours'] as num?)?.toInt() ?? 24,
      );
}

/// Riga di `public.nutritionist_details`.
class NutritionistDetails {
  final String? studioName;
  final String? bio;

  const NutritionistDetails({this.studioName, this.bio});

  factory NutritionistDetails.fromJson(Map<String, dynamic> json) => NutritionistDetails(
        studioName: json['studio_name'] as String?,
        bio: json['bio'] as String?,
      );
}

/// Riga di `public.professional_verifications`.
class ProfessionalVerification {
  final String id;
  final String licenseBody;
  final String licenseNumber;
  final String status; // pending | verified | rejected
  final DateTime? reviewedAt;

  const ProfessionalVerification({
    required this.id,
    required this.licenseBody,
    required this.licenseNumber,
    required this.status,
    this.reviewedAt,
  });

  String get statusLabel => switch (status) {
        'verified' => 'Verificato',
        'rejected' => 'Rifiutato',
        _ => 'In attesa di revisione',
      };

  factory ProfessionalVerification.fromJson(Map<String, dynamic> json) => ProfessionalVerification(
        id: json['id'] as String,
        licenseBody: (json['license_body'] as String?) ?? '',
        licenseNumber: (json['license_number'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'pending',
        reviewedAt: _date(json['reviewed_at']),
      );
}

/// Codice invito creato da un nutrizionista (valido 7 giorni).
class Invitation {
  final String code;
  final DateTime? expiresAt;

  const Invitation({required this.code, this.expiresAt});
}

/// Riga di `public.patient_links` con i consensi attivi.
class PatientLink {
  final String id;
  final String patientId;
  final String nutritionistId;
  final String status; // active | revoked
  final DateTime? createdAt;
  final Set<ConsentScope> activeScopes;

  const PatientLink({
    required this.id,
    required this.patientId,
    required this.nutritionistId,
    required this.status,
    this.createdAt,
    this.activeScopes = const {},
  });

  bool get isActive => status == 'active';

  factory PatientLink.fromJson(Map<String, dynamic> json, {Set<ConsentScope> scopes = const {}}) => PatientLink(
        id: json['id'] as String,
        patientId: json['patient_id'] as String,
        nutritionistId: json['nutritionist_id'] as String,
        status: (json['status'] as String?) ?? 'active',
        createdAt: _date(json['created_at']),
        activeScopes: scopes,
      );
}

/// Riga di `public.notifications` (non letta se `read_at` è nullo).
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.createdAt,
    this.data = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: (json['type'] as String?) ?? 'system',
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        createdAt: _date(json['created_at']),
        data: Map<String, dynamic>.from((json['data'] as Map?) ?? const {}),
      );
}

/// Riga di `public.nutritionist_comments`.
class NutritionistComment {
  final String id;
  final String body;
  final DateTime? commentDate;
  final MealSlot? slot;
  final DateTime? createdAt;
  final DateTime? readAt;

  const NutritionistComment({
    required this.id,
    required this.body,
    this.commentDate,
    this.slot,
    this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory NutritionistComment.fromJson(Map<String, dynamic> json) => NutritionistComment(
        id: json['id'] as String,
        body: (json['body'] as String?) ?? '',
        commentDate: _date(json['comment_date']),
        slot: json['meal_slot'] == null ? null : MealSlot.fromValue(json['meal_slot'] as String),
        createdAt: _date(json['created_at']),
        readAt: _date(json['read_at']),
      );
}

/// Riga di `public.food_portions`.
class FoodPortion {
  final String id;
  final String label;
  final double grams;

  const FoodPortion({required this.id, required this.label, required this.grams});

  factory FoodPortion.fromJson(Map<String, dynamic> json) => FoodPortion(
        id: json['id'] as String,
        label: (json['label'] as String?) ?? '',
        grams: _num(json['grams']),
      );
}

/// Riga di `public.personal_meals`.
class PersonalMeal {
  final String id;
  final String name;
  final MealSlot? defaultSlot;
  final int useCount;

  const PersonalMeal({required this.id, required this.name, this.defaultSlot, this.useCount = 0});

  factory PersonalMeal.fromJson(Map<String, dynamic> json) => PersonalMeal(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        defaultSlot: json['default_slot'] == null ? null : MealSlot.fromValue(json['default_slot'] as String),
        useCount: (json['use_count'] as num?)?.toInt() ?? 0,
      );
}

/// Prodotto restituito dalla Edge Function `search-off` (non ancora in catalogo).
class OffProduct {
  final String name;
  final String? brand;
  final String? barcode;
  final double kcal;

  const OffProduct({required this.name, this.brand, this.barcode, required this.kcal});

  factory OffProduct.fromJson(Map<String, dynamic> json) => OffProduct(
        name: (json['name'] as String?) ?? 'Prodotto',
        brand: json['brand'] as String?,
        barcode: json['barcode'] as String?,
        kcal: _num(json['kcal']),
      );
}

/// Riga restituita da `get_my_patients`.
class PatientOverview {
  final String patientId;
  final String displayName;
  final String linkId;
  final bool sharesAdherence;
  final DateTime? lastLoggedDate;
  final int daysLoggedLast7;
  final int daysOnTargetLast7;
  final int attentionScore;

  const PatientOverview({
    required this.patientId,
    required this.displayName,
    required this.linkId,
    required this.sharesAdherence,
    this.lastLoggedDate,
    required this.daysLoggedLast7,
    required this.daysOnTargetLast7,
    required this.attentionScore,
  });

  factory PatientOverview.fromJson(Map<String, dynamic> json) => PatientOverview(
        patientId: json['patient_id'] as String,
        displayName: (json['display_name'] as String?) ?? 'Paziente',
        linkId: json['link_id'] as String,
        sharesAdherence: (json['shares_adherence'] as bool?) ?? false,
        lastLoggedDate: _date(json['last_logged_date']),
        daysLoggedLast7: (json['days_logged_last_7'] as num?)?.toInt() ?? 0,
        daysOnTargetLast7: (json['days_on_target_last_7'] as num?)?.toInt() ?? 0,
        attentionScore: (json['attention_score'] as num?)?.toInt() ?? 0,
      );
}

/// Riga di `get_diary_with_comments`: voci e commenti di un pasto in un giorno.
class DiaryMealWithComments {
  final DateTime date;
  final MealSlot slot;
  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> comments;

  const DiaryMealWithComments({
    required this.date,
    required this.slot,
    required this.entries,
    required this.comments,
  });

  factory DiaryMealWithComments.fromJson(Map<String, dynamic> json) => DiaryMealWithComments(
        date: DateTime.parse(json['entry_date'] as String),
        slot: MealSlot.fromValue(json['meal_slot'] as String?),
        entries: List<Map<String, dynamic>>.from((json['entries'] as List?) ?? const []),
        comments: List<Map<String, dynamic>>.from((json['comments'] as List?) ?? const []),
      );
}

/// Riepilogo della Edge Function `analyze-adherence`.
class AdherenceSummary {
  final int totalDays;
  final int loggedDays;
  final int onTargetDays;
  final int adherenceRate;

  const AdherenceSummary({
    required this.totalDays,
    required this.loggedDays,
    required this.onTargetDays,
    required this.adherenceRate,
  });

  factory AdherenceSummary.fromJson(Map<String, dynamic> json) => AdherenceSummary(
        totalDays: (json['total_days'] as num?)?.toInt() ?? 0,
        loggedDays: (json['logged_days'] as num?)?.toInt() ?? 0,
        onTargetDays: (json['on_target_days'] as num?)?.toInt() ?? 0,
        adherenceRate: (json['adherence_rate'] as num?)?.toInt() ?? 0,
      );
}
