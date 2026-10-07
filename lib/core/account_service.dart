import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_error.dart';
import 'models.dart';
import 'push_service.dart';
import 'supabase.dart';

/// Versione dell'informativa accettata quando si concedono consensi.
const consentPolicyVersion = '1.0';

/// Profilo, impostazioni, verifica professionale, inviti, collegamenti e
/// consensi. L'identità arriva sempre dalla sessione (auth.uid()), mai
/// da id passati dalla UI.
class AccountService {
  static String get _uid {
    final id = supabase.auth.currentUser?.id;
    if (id == null) throw const AppError('Sessione scaduta. Accedi di nuovo.', status: 401);
    return id;
  }

  static Future<void> signOut() async {
    await PushService.unregisterDevice();
    await supabase.auth.signOut();
  }

  // --- Profilo ----------------------------------------------------------

  static Future<Profile> getProfile() {
    return withSessionRetry(() async {
      final row = await supabase.from('profiles').select().eq('id', _uid).single();
      return Profile.fromJson(row);
    });
  }

  static Future<void> updateProfile({String? displayName, String? locale}) {
    return withSessionRetry(() => supabase.from('profiles').update({
          'display_name': ?displayName,
          'locale': ?locale,
        }).eq('id', _uid));
  }

  // --- Impostazioni paziente ---------------------------------------------

  static Future<PatientSettings?> getPatientSettings() {
    return withSessionRetry(() async {
      final row = await supabase.from('patient_settings').select().eq('user_id', _uid).maybeSingle();
      return row == null ? null : PatientSettings.fromJson(row);
    });
  }

  static Future<void> updatePatientSettings(PatientSettings s) {
    return withSessionRetry(() => supabase.from('patient_settings').update({
          'dietary_restrictions': s.dietaryRestrictions,
          'timezone': s.timezone,
          'reminders_enabled': s.remindersEnabled,
          'reminder_after_hours': s.reminderAfterHours,
        }).eq('user_id', _uid));
  }

  // --- Nutrizionista ----------------------------------------------------

  static Future<NutritionistDetails?> getNutritionistDetails() {
    return withSessionRetry(() async {
      final row = await supabase.from('nutritionist_details').select().eq('user_id', _uid).maybeSingle();
      return row == null ? null : NutritionistDetails.fromJson(row);
    });
  }

  static Future<void> updateNutritionistDetails(NutritionistDetails details) {
    return withSessionRetry(() => supabase.from('nutritionist_details').upsert(
          {'user_id': _uid, ...details.toJson()},
          onConflict: 'user_id',
        ));
  }

  /// Email dell'account (sta in auth.users, non in profiles).
  static String? get email => supabase.auth.currentUser?.email;

  static Future<void> changePassword(String newPassword) =>
      withSessionRetry(() => supabase.auth.updateUser(UserAttributes(password: newPassword)));

  /// Nome e dettagli del nutrizionista collegato (RLS: solo con link attivo).
  static Future<({String name, NutritionistDetails? details})> getLinkedNutritionist(String nutritionistId) {
    return withSessionRetry(() async {
      final profile = await supabase.from('profiles').select('display_name').eq('id', nutritionistId).maybeSingle();
      final details = await supabase.from('nutritionist_details').select().eq('user_id', nutritionistId).maybeSingle();
      final name = (profile?['display_name'] as String?)?.trim();
      return (
        name: (name == null || name.isEmpty) ? 'Il tuo nutrizionista' : name,
        details: details == null ? null : NutritionistDetails.fromJson(details),
      );
    });
  }

  static Future<ProfessionalVerification?> getLatestVerification() {
    return withSessionRetry(() async {
      final row = await supabase
          .from('professional_verifications')
          .select()
          .eq('user_id', _uid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : ProfessionalVerification.fromJson(row);
    });
  }

  static Future<ProfessionalVerification> requestVerification({
    required String licenseBody,
    required String licenseNumber,
  }) {
    return withSessionRetry(() async {
      final row = await supabase
          .from('professional_verifications')
          .insert({'user_id': _uid, 'license_body': licenseBody, 'license_number': licenseNumber})
          .select()
          .single();
      return ProfessionalVerification.fromJson(row);
    });
  }

  // --- Inviti e collegamenti ----------------------------------------------

  /// Solo nutrizionisti. Il codice vale 7 giorni.
  static Future<Invitation> createInvitation() {
    return withSessionRetry(() async {
      final data = await supabase.rpc('create_invitation');
      final row = data is List ? (data.isEmpty ? null : data.first) : data;
      if (row is Map) {
        return Invitation(
          code: row['code'] as String,
          expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
        );
      }
      return Invitation(code: row.toString());
    });
  }

  /// Solo pazienti. Restituisce l'id del collegamento creato.
  static Future<String?> redeemInvitation(String code, Set<ConsentScope> scopes) {
    return withSessionRetry(() async {
      final data = await supabase.rpc('redeem_invitation', params: {
        'p_code': code.trim().toUpperCase(),
        'p_scopes': scopes.map((s) => s.name).toList(),
        'p_policy_version': consentPolicyVersion,
      });
      final row = data is List ? (data.isEmpty ? null : data.first) : data;
      if (row is Map) return (row['link_id'] ?? row['linkId'] ?? row['id'])?.toString();
      return row?.toString();
    });
  }

  /// Collegamenti dell'utente (come paziente o nutrizionista) con i
  /// consensi non revocati.
  static Future<List<PatientLink>> getMyLinks() {
    return withSessionRetry(() async {
      final uid = _uid;
      final List<Map<String, dynamic>> links = await supabase
          .from('patient_links')
          .select()
          .or('patient_id.eq.$uid,nutritionist_id.eq.$uid')
          .eq('status', 'active')
          .order('created_at', ascending: false);
      if (links.isEmpty) return <PatientLink>[];

      final List<Map<String, dynamic>> consents = await supabase
          .from('consents')
          .select('link_id, scope')
          .inFilter('link_id', links.map((l) => l['id']).toList())
          .isFilter('revoked_at', null);
      final scopesByLink = <String, Set<ConsentScope>>{};
      for (final c in consents) {
        final scope = ConsentScope.fromValue(c['scope'] as String?);
        if (scope != null) scopesByLink.putIfAbsent(c['link_id'] as String, () => {}).add(scope);
      }
      return [for (final l in links) PatientLink.fromJson(l, scopes: scopesByLink[l['id']] ?? const {})];
    });
  }

  static Future<void> revokeLink(String linkId) {
    return withSessionRetry(() => supabase.rpc('revoke_link', params: {'p_link_id': linkId}));
  }

  // --- Consensi (GDPR, solo pazienti) -------------------------------------

  static Future<void> grantConsent(String linkId, ConsentScope scope) {
    return withSessionRetry(() => supabase.rpc('grant_consent', params: {
          'p_link_id': linkId,
          'p_scope': scope.name,
          'p_policy_version': consentPolicyVersion,
        }));
  }

  static Future<void> revokeConsent(String linkId, ConsentScope scope) {
    return withSessionRetry(() => supabase.rpc('revoke_consent', params: {
          'p_link_id': linkId,
          'p_scope': scope.name,
        }));
  }
}
