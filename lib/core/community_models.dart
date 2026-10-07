import 'models.dart';

/// Come in models.dart: un `numeric` che arrivasse come stringa non deve
/// far fallire la schermata.
double _num(dynamic v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s.replaceFirst(',', '.')) ?? 0,
      _ => 0,
    };
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
List<String> _strings(dynamic v) => List<String>.from((v as List?) ?? const []);
String? _text(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Obiettivi assegnabili a ricette e piani di base. I valori sono quelli
/// ammessi dal vincolo suggested_meals_goal_tags_check: cambiarli fa
/// rifiutare il salvataggio dal database.
const goalTagLabels = {
  'high_protein': 'Ricco di proteine',
  'low_carb': 'Pochi carboidrati',
  'low_fat': 'Pochi grassi',
  'high_fiber': 'Ricco di fibre',
  'balanced': 'Bilanciato',
};

/// Specializzazioni mostrate nella vetrina dei nutrizionisti.
const specialtyLabels = {
  'sport': 'Nutrizione sportiva',
  'weight_loss': 'Dimagrimento',
  'plant_based': 'Alimentazione vegetale',
  'intolerances': 'Intolleranze',
  'clinical': 'Nutrizione clinica',
  'pregnancy': 'Gravidanza',
  'pediatric': 'Pediatrica',
  'diabetes': 'Diabete',
};

const professionLabels = {
  'nutritionist': 'Nutrizionista',
  'dietitian': 'Dietista',
  'personal_trainer': 'Personal trainer',
};

/// Riga di `suggested_meals` (ricetta) con eventuali ingredienti.
class Recipe {
  final String id;
  final String title;
  final String? description;
  final String? instructions;
  final List<MealSlot> slots;
  final int servings;
  final List<String> restrictionTags;
  final List<String> goalTags;
  final String? socialUrl;
  final String? imageUrl;
  final int? prepMinutes;
  final String visibility; // public | patients
  final String status; // draft | pending_review | approved | rejected
  final String? reviewNotes;
  final double kcalPerServing;
  final double proteinPerServing;
  final double carbsPerServing;
  final double fatPerServing;
  final String? authorId;
  final String? authorName;
  final String? authorRole;
  final bool fromMyNutritionist;
  final List<RecipeIngredient> ingredients;

  const Recipe({
    required this.id,
    required this.title,
    this.description,
    this.instructions,
    this.slots = const [],
    this.servings = 1,
    this.restrictionTags = const [],
    this.goalTags = const [],
    this.socialUrl,
    this.imageUrl,
    this.prepMinutes,
    this.visibility = 'public',
    this.status = 'approved',
    this.reviewNotes,
    this.kcalPerServing = 0,
    this.proteinPerServing = 0,
    this.carbsPerServing = 0,
    this.fatPerServing = 0,
    this.authorId,
    this.authorName,
    this.authorRole,
    this.fromMyNutritionist = false,
    this.ingredients = const [],
  });

  bool get isApproved => status == 'approved';
  bool get isEditable => status == 'draft' || status == 'rejected';
  bool get byProfessional => authorRole == 'nutritionist' || authorRole == 'admin';

  String get statusLabel => switch (status) {
        'draft' => 'Bozza',
        'pending_review' => 'In revisione',
        'approved' => visibility == 'patients' ? 'Pubblicata per i pazienti' : 'Pubblicata',
        'rejected' => 'Da correggere',
        _ => status,
      };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final servings = (json['servings'] as num?)?.toInt() ?? 1;
    double perServing(String perKey, String totalKey) =>
        json[perKey] != null ? _num(json[perKey]) : _num(json[totalKey]) / (servings < 1 ? 1 : servings);
    return Recipe(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      description: _text(json['description']),
      instructions: _text(json['instructions']),
      slots: _strings(json['meal_slots']).map(MealSlot.fromValue).toList(),
      servings: servings,
      restrictionTags: _strings(json['restriction_tags']),
      goalTags: _strings(json['goal_tags']),
      socialUrl: _text(json['social_url']),
      imageUrl: _text(json['image_url']),
      prepMinutes: (json['prep_minutes'] as num?)?.toInt(),
      visibility: (json['visibility'] as String?) ?? 'public',
      status: (json['status'] as String?) ?? 'approved',
      reviewNotes: _text(json['review_notes']),
      kcalPerServing: perServing('kcal_per_serving', 'kcal_total'),
      proteinPerServing: perServing('protein_g_per_serving', 'protein_g_total'),
      carbsPerServing: perServing('carbs_g_per_serving', 'carbs_g_total'),
      fatPerServing: perServing('fat_g_per_serving', 'fat_g_total'),
      authorId: (json['author_id'] ?? json['proposed_by']) as String?,
      authorName: _text(json['author_name']),
      authorRole: (json['author_role'] ?? json['proposer_role']) as String?,
      fromMyNutritionist: (json['from_my_nutritionist'] as bool?) ?? false,
      ingredients: ((json['suggested_meal_items'] as List?) ?? const [])
          .map((i) => RecipeIngredient.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position)),
    );
  }
}

/// Riga di `suggested_meal_items` con l'alimento collegato.
class RecipeIngredient {
  final String? id;
  final Food food;
  final double grams;
  final int position;
  final String? note;

  const RecipeIngredient({this.id, required this.food, required this.grams, this.position = 0, this.note});

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
        id: json['id'] as String?,
        food: Food.fromJson(Map<String, dynamic>.from(json['foods'] as Map)),
        grams: _num(json['grams']),
        position: (json['position'] as num?)?.toInt() ?? 0,
        note: _text(json['note']),
      );
}

/// Ricetta di un paziente in attesa di revisione (`get_meals_to_review`).
class RecipeToReview {
  final String id;
  final String title;
  final String? authorName;
  final DateTime? createdAt;
  final double kcalTotal;

  const RecipeToReview({required this.id, required this.title, this.authorName, this.createdAt, this.kcalTotal = 0});

  factory RecipeToReview.fromJson(Map<String, dynamic> json) => RecipeToReview(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        authorName: _text(json['author_name']),
        createdAt: _date(json['created_at']),
        kcalTotal: _num(json['kcal_total']),
      );
}

/// Link social e sito di un nutrizionista.
class SocialLinks {
  final String? instagram;
  final String? tiktok;
  final String? youtube;
  final String? website;

  const SocialLinks({this.instagram, this.tiktok, this.youtube, this.website});

  bool get isEmpty => instagram == null && tiktok == null && youtube == null && website == null;

  factory SocialLinks.fromJson(Map<String, dynamic> json) => SocialLinks(
        instagram: _text(json['instagram_url']),
        tiktok: _text(json['tiktok_url']),
        youtube: _text(json['youtube_url']),
        website: _text(json['website_url']),
      );
}

/// Scheda di un nutrizionista nella vetrina (`search_nutritionists`).
class NutritionistCard {
  final String id;
  final String displayName;
  final String profession;
  final String? headline;
  final String? studioName;
  final String? bio;
  final List<String> specialties;
  final String? city;
  final bool online;
  final bool acceptingPatients;
  final SocialLinks socials;
  final int recipesCount;
  final int plansCount;
  final bool isMyNutritionist;

  const NutritionistCard({
    required this.id,
    required this.displayName,
    this.profession = 'nutritionist',
    this.headline,
    this.studioName,
    this.bio,
    this.specialties = const [],
    this.city,
    this.online = true,
    this.acceptingPatients = true,
    this.socials = const SocialLinks(),
    this.recipesCount = 0,
    this.plansCount = 0,
    this.isMyNutritionist = false,
  });

  String get professionLabel => professionLabels[profession] ?? 'Nutrizionista';

  factory NutritionistCard.fromJson(Map<String, dynamic> json) => NutritionistCard(
        id: json['id'] as String,
        displayName: (json['display_name'] as String?) ?? 'Nutrizionista',
        profession: (json['profession'] as String?) ?? 'nutritionist',
        headline: _text(json['headline']),
        studioName: _text(json['studio_name']),
        bio: _text(json['bio']),
        specialties: _strings(json['specialties']),
        city: _text(json['city']),
        online: (json['online_consultations'] as bool?) ?? true,
        acceptingPatients: (json['accepting_patients'] as bool?) ?? true,
        socials: SocialLinks.fromJson(json),
        recipesCount: (json['recipes_count'] as num?)?.toInt() ?? 0,
        plansCount: (json['plans_count'] as num?)?.toInt() ?? 0,
        isMyNutritionist: (json['is_my_nutritionist'] as bool?) ?? false,
      );
}

/// Riga di `nutritionist_plan_templates`: piano alimentare "di base" in vetrina.
class PlanTemplate {
  final String? id;
  final String title;
  final String? description;
  final List<String> goalTags;
  final List<String> restrictionTags;
  final double? kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final int? durationWeeks;
  final String? priceLabel;
  final bool isPublished;

  const PlanTemplate({
    this.id,
    required this.title,
    this.description,
    this.goalTags = const [],
    this.restrictionTags = const [],
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.durationWeeks,
    this.priceLabel,
    this.isPublished = false,
  });

  factory PlanTemplate.fromJson(Map<String, dynamic> json) => PlanTemplate(
        id: json['id'] as String?,
        title: (json['title'] as String?) ?? '',
        description: _text(json['description']),
        goalTags: _strings(json['goal_tags']),
        restrictionTags: _strings(json['restriction_tags']),
        kcal: (json['kcal'] as num?)?.toDouble(),
        proteinG: (json['protein_g'] as num?)?.toDouble(),
        carbsG: (json['carbs_g'] as num?)?.toDouble(),
        fatG: (json['fat_g'] as num?)?.toDouble(),
        durationWeeks: (json['duration_weeks'] as num?)?.toInt(),
        priceLabel: _text(json['price_label']),
        isPublished: (json['is_published'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'goal_tags': goalTags,
        'restriction_tags': restrictionTags,
        'kcal': kcal,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'duration_weeks': durationWeeks,
        'price_label': priceLabel,
        'is_published': isPublished,
      };
}

/// Riga di `get_my_conversations`.
class Conversation {
  final String id;
  final String otherId;
  final String otherName;
  final String otherRole;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool linked;

  const Conversation({
    required this.id,
    required this.otherId,
    required this.otherName,
    required this.otherRole,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.linked = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        otherId: json['other_id'] as String,
        otherName: _text(json['other_name']) ?? 'Utente',
        otherRole: (json['other_role'] as String?) ?? 'patient',
        lastMessage: _text(json['last_message']),
        lastMessageAt: _date(json['last_message_at']),
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
        linked: (json['linked'] as bool?) ?? false,
      );
}

/// Riga di `messages`.
class ChatMessage {
  final String id;
  final String senderId;
  final String kind; // text | invite | recipe
  final String body;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? readAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.body,
    this.payload = const {},
    required this.createdAt,
    this.readAt,
  });

  String? get inviteCode => kind == 'invite' ? payload['code'] as String? : null;
  String? get recipeId => kind == 'recipe' ? payload['recipe_id'] as String? : null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        kind: (json['kind'] as String?) ?? 'text',
        body: (json['body'] as String?) ?? '',
        payload: Map<String, dynamic>.from((json['payload'] as Map?) ?? const {}),
        createdAt: _date(json['created_at']) ?? DateTime.now(),
        readAt: _date(json['read_at']),
      );
}

/// Riga di `get_patient_suggestions`: una ricetta o un alimento che il
/// professionista ha indicato a quel paziente in particolare.
class PatientSuggestion {
  final String id;

  /// `recipe` oppure `food`.
  final String kind;
  final String? mealId;
  final String? foodId;
  final String title;
  final String? note;

  /// Per una ricetta è una porzione, per un alimento 100 g.
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final List<MealSlot> slots;
  final String authorName;
  final DateTime? createdAt;

  const PatientSuggestion({
    required this.id,
    required this.kind,
    this.mealId,
    this.foodId,
    required this.title,
    this.note,
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.slots = const [],
    this.authorName = 'Il tuo nutrizionista',
    this.createdAt,
  });

  bool get isRecipe => kind == 'recipe';

  /// "una porzione" o "100 g": l'unità a cui si riferiscono i valori.
  String get portionLabel => isRecipe ? 'una porzione' : '100 g';

  factory PatientSuggestion.fromJson(Map<String, dynamic> json) => PatientSuggestion(
        id: json['id'] as String,
        kind: (json['kind'] as String?) ?? 'food',
        mealId: json['meal_id'] as String?,
        foodId: json['food_id'] as String?,
        title: (json['title'] as String?) ?? 'Consiglio',
        note: _text(json['note']),
        kcal: _num(json['kcal']),
        proteinG: _num(json['protein_g']),
        carbsG: _num(json['carbs_g']),
        fatG: _num(json['fat_g']),
        slots: _strings(json['meal_slots']).map(MealSlot.fromValue).toList(),
        authorName: (json['author_name'] as String?) ?? 'Il tuo nutrizionista',
        createdAt: _date(json['created_at']),
      );
}
