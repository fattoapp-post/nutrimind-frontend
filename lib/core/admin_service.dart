import 'app_error.dart';
import 'supabase.dart';

/// Numeri del progetto, per chi amministra (`get_admin_overview`).
class AdminOverview {
  final int pendingVerifications;
  final int foodsToReview;
  final int mealsToReview;
  final int patients;
  final int professionals;
  final int verifiedProfessionals;
  final int publicProfessionals;
  final int activeLinks;
  final int foodsTotal;
  final int foodsVerified;
  final int recipesPublished;
  final int diaryEntriesLast7;

  const AdminOverview({
    this.pendingVerifications = 0,
    this.foodsToReview = 0,
    this.mealsToReview = 0,
    this.patients = 0,
    this.professionals = 0,
    this.verifiedProfessionals = 0,
    this.publicProfessionals = 0,
    this.activeLinks = 0,
    this.foodsTotal = 0,
    this.foodsVerified = 0,
    this.recipesPublished = 0,
    this.diaryEntriesLast7 = 0,
  });

  /// Quante cose aspettano una decisione: è il numero che conta.
  int get pendingTotal => pendingVerifications + foodsToReview + mealsToReview;

  static int _int(dynamic v) => switch (v) {
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      };

  factory AdminOverview.fromJson(Map<String, dynamic> j) => AdminOverview(
        pendingVerifications: _int(j['pending_verifications']),
        foodsToReview: _int(j['foods_to_review']),
        mealsToReview: _int(j['meals_to_review']),
        patients: _int(j['patients']),
        professionals: _int(j['professionals']),
        verifiedProfessionals: _int(j['verified_professionals']),
        publicProfessionals: _int(j['public_professionals']),
        activeLinks: _int(j['active_links']),
        foodsTotal: _int(j['foods_total']),
        foodsVerified: _int(j['foods_verified']),
        recipesPublished: _int(j['recipes_published']),
        diaryEntriesLast7: _int(j['diary_entries_last_7']),
      );
}

/// Un alimento in attesa di revisione (`get_foods_to_review`).
class FoodToReview {
  final String id;
  final String name;
  final String? brand;
  final String source;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String? servingLabel;
  final String? barcode;
  final String authorName;

  /// L'ho creato io: un non amministratore non può rivederlo.
  final bool isMine;
  final DateTime? createdAt;

  const FoodToReview({
    required this.id,
    required this.name,
    this.brand,
    required this.source,
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.servingLabel,
    this.barcode,
    this.authorName = 'Utente',
    this.isMine = false,
    this.createdAt,
  });

  /// La somma dei macro non può superare 100 g su 100 g di prodotto, e le
  /// calorie devono essere coerenti: due controlli che aiutano chi
  /// decide senza avere la confezione in mano.
  bool get macrosPlausible => proteinG + carbsG + fatG <= 100.5;

  double get kcalFromMacros => proteinG * 4 + carbsG * 4 + fatG * 9;

  bool get kcalPlausible => kcal <= 0 || (kcal - kcalFromMacros).abs() <= kcal * 0.25 + 15;

  static double _num(dynamic v) => switch (v) {
        num n => n.toDouble(),
        String s => double.tryParse(s) ?? 0,
        _ => 0,
      };

  factory FoodToReview.fromJson(Map<String, dynamic> j) => FoodToReview(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Alimento',
        brand: j['brand'] as String?,
        source: (j['source'] as String?) ?? 'user',
        kcal: _num(j['kcal']),
        proteinG: _num(j['protein_g']),
        carbsG: _num(j['carbs_g']),
        fatG: _num(j['fat_g']),
        servingLabel: j['serving_label'] as String?,
        barcode: j['barcode'] as String?,
        authorName: (j['author_name'] as String?) ?? 'Utente',
        isMine: (j['is_mine'] as bool?) ?? false,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
      );
}

/// Operazioni riservate ad amministratori e professionisti verificati.
class AdminService {
  static Future<AdminOverview> getOverview() {
    return withSessionRetry(() async {
      final data = await supabase.rpc('get_admin_overview');
      return AdminOverview.fromJson(Map<String, dynamic>.from(data as Map));
    });
  }

  /// Coda degli alimenti scritti dalle persone e mai verificati.
  /// `review_food` esisteva dall'inizio ma nessuna schermata la usava:
  /// gli alimenti restavano `unverified` per sempre.
  static Future<List<FoodToReview>> getFoodsToReview({int limit = 50}) {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_foods_to_review', params: {'p_limit': limit}) as List;
      return rows.map((r) => FoodToReview.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    });
  }

  static Future<void> reviewFood(String foodId, {required bool approve}) {
    return withSessionRetry(() => supabase.rpc('review_food', params: {
          'p_food_id': foodId,
          'p_decision': approve ? 'verified' : 'rejected',
        }));
  }

  /// Richieste di abilitazione professionale (`get_pending_verifications`).
  static Future<List<Map<String, dynamic>>> getVerifications() {
    return withSessionRetry(() async {
      final rows = await supabase.rpc('get_pending_verifications') as List;
      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    });
  }

  static Future<void> reviewVerification(String id, {required bool approve}) {
    return withSessionRetry(() => supabase.rpc('review_professional_verification', params: {
          'p_id': id,
          'p_approve': approve,
        }));
  }
}
