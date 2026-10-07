/// Numero preso da una risposta del database. I campi `numeric` di
/// Postgres arrivano di solito come numeri JSON, ma non sempre: un cast
/// secco andrebbe in errore e farebbe fallire tutta la schermata.
double? _numOrNull(dynamic v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s.replaceFirst(',', '.')),
      _ => null,
    };
double _num(dynamic v) => _numOrNull(v) ?? 0;

/// Marca da mostrare accanto al nome di un prodotto. Restituisce null
/// quando non c'è o quando ripete il nome stesso: nel catalogo esteso
/// capita spesso ("Nutella" di marca "Nutella") e scrivere due volte la
/// stessa parola fa solo rumore.
String? _brandLabel(String? brand, String name) {
  final b = brand?.trim();
  if (b == null || b.isEmpty) return null;
  return b.toLowerCase() == name.trim().toLowerCase() ? null : b;
}

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
  // Dettagli nutrizionali e di prodotto (colonne opzionali, 003b/013)
  final double? fiberG;
  final double? sugarsG;
  final double? saturatedFatG;
  final double? saltG;
  final String? nutriscoreGrade;
  final int? novaGroup;
  final String? ingredientsText;
  final String? allergensText;
  final String? tracesText;
  final String? quantityText;
  final String? imageUrl;

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
    this.fiberG,
    this.sugarsG,
    this.saturatedFatG,
    this.saltG,
    this.nutriscoreGrade,
    this.novaGroup,
    this.ingredientsText,
    this.allergensText,
    this.tracesText,
    this.quantityText,
    this.imageUrl,
  });

  bool get isVerified => verification == 'verified';

  /// Alimento creato da un utente e non ancora revisionato.
  bool get isUserCreated => source == 'user';

  /// Marca da mostrare accanto al nome, oppure null.
  String? get brandLabel => _brandLabel(brand, name);

  /// Marca e porzione sotto il nome del prodotto.
  String get subtitle =>
      [brandLabel, servingLabel].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  static String? _text(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

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
        fiberG: _numOrNull(json['fiber_g']),
        sugarsG: _numOrNull(json['sugars_g']),
        saturatedFatG: _numOrNull(json['saturated_fat_g']),
        saltG: _numOrNull(json['salt_g']),
        nutriscoreGrade: _text(json['nutriscore_grade'])?.toUpperCase(),
        novaGroup: (json['nova_group'] as num?)?.toInt(),
        ingredientsText: _text(json['ingredients_text']),
        allergensText: _text(json['allergens_text']),
        tracesText: _text(json['traces_text']),
        quantityText: _text(json['quantity_text']),
        imageUrl: _text(json['image_front_url']),
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
  final String? planName;
  /// kcal obiettivo per pasto (solo pasti presenti nel piano).
  final Map<MealSlot, double> kcalBySlot;

  const DailyTargets({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fromPlan,
    this.planName,
    this.kcalBySlot = const {},
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
  // Profilo pubblico (migration 016)
  final String profession; // nutritionist | dietitian | personal_trainer
  final String? headline;
  final List<String> specialties;
  final String? city;
  final bool onlineConsultations;
  final bool acceptingPatients;
  final bool isPublic;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? youtubeUrl;
  final String? websiteUrl;

  const NutritionistDetails({
    this.studioName,
    this.bio,
    this.profession = 'nutritionist',
    this.headline,
    this.specialties = const [],
    this.city,
    this.onlineConsultations = true,
    this.acceptingPatients = true,
    this.isPublic = false,
    this.instagramUrl,
    this.tiktokUrl,
    this.youtubeUrl,
    this.websiteUrl,
  });

  factory NutritionistDetails.fromJson(Map<String, dynamic> json) => NutritionistDetails(
        studioName: json['studio_name'] as String?,
        bio: json['bio'] as String?,
        profession: (json['profession'] as String?) ?? 'nutritionist',
        headline: json['headline'] as String?,
        specialties: List<String>.from((json['specialties'] as List?) ?? const []),
        city: json['city'] as String?,
        onlineConsultations: (json['online_consultations'] as bool?) ?? true,
        acceptingPatients: (json['accepting_patients'] as bool?) ?? true,
        isPublic: (json['is_public'] as bool?) ?? false,
        instagramUrl: json['instagram_url'] as String?,
        tiktokUrl: json['tiktok_url'] as String?,
        youtubeUrl: json['youtube_url'] as String?,
        websiteUrl: json['website_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'studio_name': studioName,
        'bio': bio,
        'profession': profession,
        'headline': headline,
        'specialties': specialties,
        'city': city,
        'online_consultations': onlineConsultations,
        'accepting_patients': acceptingPatients,
        'is_public': isPublic,
        'instagram_url': instagramUrl,
        'tiktok_url': tiktokUrl,
        'youtube_url': youtubeUrl,
        'website_url': websiteUrl,
      };
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

/// Filtri sui valori nutrizionali per 100 g usati da `search_foods`.
class NutrientFilters {
  final double? minProtein;
  final double? maxProtein;
  final double? minCarbs;
  final double? maxCarbs;
  final double? minFat;
  final double? maxFat;
  final double? minKcal;
  final double? maxKcal;

  /// null | protein_desc | carbs_asc | fat_asc | kcal_asc | kcal_desc
  final String? sort;

  const NutrientFilters({
    this.minProtein,
    this.maxProtein,
    this.minCarbs,
    this.maxCarbs,
    this.minFat,
    this.maxFat,
    this.minKcal,
    this.maxKcal,
    this.sort,
  });

  static const none = NutrientFilters();

  List<double?> get _bounds => [minProtein, maxProtein, minCarbs, maxCarbs, minFat, maxFat, minKcal, maxKcal];

  bool get hasBounds => _bounds.any((v) => v != null);
  bool get isActive => hasBounds || sort != null;
  int get activeCount => _bounds.where((v) => v != null).length + (sort == null ? 0 : 1);

  /// Riassunto per l'utente, es. "Proteine ≥ 50 g · Grassi ≤ 10 g".
  String get summary {
    final parts = <String>[
      if (minProtein != null) 'Proteine ≥ ${_fmt(minProtein!)} g',
      if (maxProtein != null) 'Proteine ≤ ${_fmt(maxProtein!)} g',
      if (minCarbs != null) 'Carboidrati ≥ ${_fmt(minCarbs!)} g',
      if (maxCarbs != null) 'Carboidrati ≤ ${_fmt(maxCarbs!)} g',
      if (minFat != null) 'Grassi ≥ ${_fmt(minFat!)} g',
      if (maxFat != null) 'Grassi ≤ ${_fmt(maxFat!)} g',
      if (minKcal != null) 'Calorie ≥ ${_fmt(minKcal!)}',
      if (maxKcal != null) 'Calorie ≤ ${_fmt(maxKcal!)}',
      if (sort != null) sortLabels[sort!] ?? '',
    ];
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  static const sortLabels = {
    'protein_desc': 'Più proteici',
    'carbs_asc': 'Meno carboidrati',
    'fat_asc': 'Meno grassi',
    'kcal_asc': 'Meno calorie',
    'kcal_desc': 'Più calorie',
  };

  Map<String, dynamic> toParams() => {
        if (minProtein != null) 'p_min_protein': minProtein,
        if (maxProtein != null) 'p_max_protein': maxProtein,
        if (minCarbs != null) 'p_min_carbs': minCarbs,
        if (maxCarbs != null) 'p_max_carbs': maxCarbs,
        if (minFat != null) 'p_min_fat': minFat,
        if (maxFat != null) 'p_max_fat': maxFat,
        if (minKcal != null) 'p_min_kcal': minKcal,
        if (maxKcal != null) 'p_max_kcal': maxKcal,
        if (sort != null) 'p_sort': sort,
      };
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

  /// Notifica di un messaggio in chat: ha il suo badge, quindi non si
  /// conta tra le notifiche generiche. Il tipo è 'system' con
  /// data.kind = 'new_message' (vedi migration 018).
  bool get isMessage => type == 'new_message' || data['kind'] == 'new_message' || data['conversation_id'] != null;

  String? get conversationId => data['conversation_id'] as String?;

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

/// Prodotto del catalogo esteso (Edge Function `search-off`), non ancora
/// importato in `foods`. Le chiavi sono le stesse della tabella.
class OffProduct {
  final String name;
  final String? brand;
  final String? barcode;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String? nutriscoreGrade;

  const OffProduct({
    required this.name,
    this.brand,
    this.barcode,
    required this.kcal,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.nutriscoreGrade,
  });

  factory OffProduct.fromJson(Map<String, dynamic> json) => OffProduct(
        name: (json['name'] as String?) ?? 'Prodotto',
        brand: json['brand'] as String?,
        barcode: json['barcode'] as String?,
        kcal: _num(json['kcal']),
        proteinG: _num(json['protein_g']),
        carbsG: _num(json['carbs_g']),
        fatG: _num(json['fat_g']),
        nutriscoreGrade: (json['nutriscore_grade'] as String?)?.toUpperCase(),
      );

  /// Marca da mostrare accanto al nome, oppure null.
  String? get brandLabel => _brandLabel(brand, name);

  /// Rispetta i filtri nutrizionali impostati dall'utente? Il catalogo
  /// esterno non li applica, quindi si filtra qui.
  bool matches(NutrientFilters f) {
    bool ok(double? min, double? max, double v) => (min == null || v >= min) && (max == null || v <= max);
    return ok(f.minProtein, f.maxProtein, proteinG) &&
        ok(f.minCarbs, f.maxCarbs, carbsG) &&
        ok(f.minFat, f.maxFat, fatG) &&
        ok(f.minKcal, f.maxKcal, kcal);
  }
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
  final int planDays;
  final int onTargetDays;
  final int adherenceRate;
  final List<AdherenceDay> days;

  const AdherenceSummary({
    required this.totalDays,
    required this.loggedDays,
    required this.planDays,
    required this.onTargetDays,
    required this.adherenceRate,
    this.days = const [],
  });

  /// Giorni consecutivi con almeno una registrazione, fino all'ultimo
  /// giorno del periodo (oggi non registrato non interrompe la serie).
  int get loggingStreak {
    var streak = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      if (days[i].logged) {
        streak++;
      } else if (i != days.length - 1) {
        break;
      }
    }
    return streak;
  }

  double get averageKcalLogged {
    final logged = days.where((d) => d.logged).toList();
    if (logged.isEmpty) return 0;
    return logged.fold(0.0, (s, d) => s + d.kcal) / logged.length;
  }

  factory AdherenceSummary.fromJson(Map<String, dynamic> json) => AdherenceSummary(
        totalDays: (json['total_days'] as num?)?.toInt() ?? 0,
        loggedDays: (json['logged_days'] as num?)?.toInt() ?? 0,
        planDays: (json['plan_days'] as num?)?.toInt() ?? 0,
        onTargetDays: (json['on_target_days'] as num?)?.toInt() ?? 0,
        adherenceRate: (json['adherence_rate'] as num?)?.toInt() ?? 0,
        days: ((json['daily_breakdown'] as List?) ?? const [])
            .map((d) => AdherenceDay.fromJson(Map<String, dynamic>.from(d as Map)))
            .toList(),
      );
}

/// Un giorno di `daily_breakdown` di `analyze-adherence`.
class AdherenceDay {
  final DateTime date;
  final bool logged;
  final bool hasPlan;
  final bool? onTarget;
  final double kcal;
  final double targetKcal;
  final double protein;
  final double targetProtein;
  final double carbs;
  final double targetCarbs;
  final double fat;
  final double targetFat;

  const AdherenceDay({
    required this.date,
    required this.logged,
    required this.hasPlan,
    this.onTarget,
    required this.kcal,
    required this.targetKcal,
    required this.protein,
    required this.targetProtein,
    required this.carbs,
    required this.targetCarbs,
    required this.fat,
    required this.targetFat,
  });

  factory AdherenceDay.fromJson(Map<String, dynamic> json) => AdherenceDay(
        date: DateTime.parse(json['date'] as String),
        logged: (json['logged'] as bool?) ?? false,
        hasPlan: (json['has_plan'] as bool?) ?? ((json['target_kcal'] as num?) ?? 0) > 0,
        onTarget: json['on_target'] as bool?,
        kcal: _num(json['total_kcal']),
        targetKcal: _num(json['target_kcal']),
        protein: _num(json['total_protein']),
        targetProtein: _num(json['target_protein']),
        carbs: _num(json['total_carbs']),
        targetCarbs: _num(json['target_carbs']),
        fat: _num(json['total_fat']),
        targetFat: _num(json['target_fat']),
      );
}
