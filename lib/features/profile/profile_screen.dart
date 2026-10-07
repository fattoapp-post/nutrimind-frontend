import 'package:flutter/material.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/chat_service.dart';
import '../../core/community_models.dart';
import '../../core/models.dart';
import '../../core/widgets/custom_bottom_nav.dart';
import '../auth/auth_gate.dart';
import '../chat/conversations_screen.dart';
import '../directory/find_nutritionist_screen.dart';
import '../notifications/notifications_screen.dart';
import '../nutritionist/plan_templates_screen.dart';
import '../recipes/my_recipes_screen.dart';
import '../shell/patient_shell.dart';
import 'account_details_screen.dart';
import 'invitations_screen.dart';
import 'my_nutritionist_screen.dart';
import 'preferences_screen.dart';
import 'profile_widgets.dart';
import 'public_profile_editor_screen.dart';
import 'verification_screen.dart';

/// Hub del profilo: scheda personale in alto e voci raggruppate, diverse per
/// paziente e professionista. Ogni voce apre una pagina dedicata.
class ProfileScreen extends StatefulWidget {
  /// Paziente: barra di navigazione della shell.
  final bool showBottomNav;

  /// Professionista: scheda dell'app nutrizionista (nessun tasto indietro).
  final bool embedded;

  const ProfileScreen({super.key, this.showBottomNav = true, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with ReloadOnTabVisible {
  Profile? _profile;
  String? _nutritionistName;
  NutritionistDetails? _details;
  ProfessionalVerification? _verification;
  int _unread = 0;
  bool _loading = true;
  String? _error;

  @override
  int get tabIndex => PatientTab.profile;

  @override
  void onTabVisible() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _profile == null;
      _error = null;
    });
    try {
      final profile = await AccountService.getProfile();
      String? nutritionistName;
      NutritionistDetails? details;
      ProfessionalVerification? verification;
      if (profile.isNutritionist) {
        details = await AccountService.getNutritionistDetails();
        verification = await AccountService.getLatestVerification();
      } else {
        final links = await AccountService.getMyLinks();
        if (links.isNotEmpty) {
          nutritionistName = (await AccountService.getLinkedNutritionist(links.first.nutritionistId)).name;
        }
      }
      var unread = 0;
      try {
        unread = await ChatService.unreadCount();
      } on AppError {
        // la chat è secondaria: il profilo si mostra comunque
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nutritionistName = nutritionistName;
        _details = details;
        _verification = verification;
        _unread = unread;
      });
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _load());

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vuoi uscire?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Esci')),
        ],
      ),
    );
    if (ok != true) return;
    await AccountService.signOut();
    // La shell potrebbe non avere AuthGate sotto di sé: si riparte da lì
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: ProfilePalette.bg,
      appBar: AppBar(
        backgroundColor: ProfilePalette.bg,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded && !widget.showBottomNav,
        title: const Text('Profilo', style: TextStyle(color: ProfilePalette.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: widget.showBottomNav && !widget.embedded
          ? const CustomBottomNav(currentIndex: PatientTab.profile, isDarkMode: false)
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ProfilePalette.teal))
          : (_error != null || profile == null)
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error ?? 'Profilo non disponibile', style: const TextStyle(color: ProfilePalette.textSecondary)),
                    TextButton(onPressed: _load, child: const Text('Riprova')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(profile),
                      const SizedBox(height: 8),
                      ...(profile.isNutritionist ? _nutritionistMenu(profile) : _patientMenu(profile)),
                      MenuGroup(title: 'Account', items: [
                        MenuItem(
                          icon: Icons.person_outline,
                          title: 'Dati personali',
                          subtitle: 'Nome, lingua, password',
                          onTap: () => _open(AccountDetailsScreen(profile: profile)),
                        ),
                        MenuItem(
                          icon: Icons.notifications_outlined,
                          title: 'Notifiche',
                          onTap: () => _open(const NotificationsScreen()),
                        ),
                        MenuItem(
                          icon: Icons.logout,
                          title: 'Esci',
                          color: Colors.red,
                          trailing: const SizedBox.shrink(),
                          onTap: _confirmSignOut,
                        ),
                      ]),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(Profile profile) {
    final name = profile.displayName.isEmpty ? 'Utente' : profile.displayName;
    final roleLabel = profile.isNutritionist
        ? (professionLabels[_details?.profession] ?? 'Nutrizionista')
        : 'Paziente';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF127B6D), Color(0xFF0E5F55)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            if (AccountService.email != null)
              Text(AccountService.email!, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _pill(roleLabel, Icons.badge_outlined),
              if (profile.isNutritionist)
                _pill(profile.professionalVerified ? 'Verificato' : 'Da verificare',
                    profile.professionalVerified ? Icons.verified : Icons.hourglass_empty),
            ]),
          ]),
        ),
        IconButton(
          tooltip: 'Modifica',
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          onPressed: () => _open(AccountDetailsScreen(profile: profile)),
        ),
      ]),
    );
  }

  Widget _pill(String text, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  List<Widget> _patientMenu(Profile profile) {
    return [
      MenuGroup(title: 'Il mio percorso', items: [
        MenuItem(
          icon: Icons.health_and_safety_outlined,
          title: 'Il mio nutrizionista',
          subtitle: _nutritionistName ?? 'Non sei collegato · trovane uno',
          onTap: () => _open(const MyNutritionistScreen()),
        ),
        MenuItem(
          icon: Icons.chat_bubble_outline,
          title: 'Messaggi',
          badge: _unread,
          onTap: () => _open(const ConversationsScreen()),
        ),
        MenuItem(
          icon: Icons.travel_explore,
          title: 'Trova un nutrizionista',
          subtitle: 'Ricette, piani di base e contatto diretto',
          onTap: () => _open(const FindNutritionistScreen()),
        ),
        MenuItem(
          icon: Icons.menu_book_outlined,
          title: 'Le mie ricette',
          subtitle: 'Creale e falle verificare dal nutrizionista',
          onTap: () => _open(const MyRecipesScreen()),
        ),
      ]),
      MenuGroup(title: 'Preferenze', items: [
        MenuItem(
          icon: Icons.no_food_outlined,
          title: 'Alimentazione e promemoria',
          subtitle: 'Restrizioni, scelte alimentari, avvisi',
          onTap: () => _open(const PreferencesScreen()),
        ),
        MenuItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy e consensi',
          subtitle: 'Cosa condividi con il nutrizionista',
          onTap: () => _open(const MyNutritionistScreen()),
        ),
      ]),
    ];
  }

  List<Widget> _nutritionistMenu(Profile profile) {
    final v = _verification;
    final verificationSubtitle = profile.professionalVerified
        ? 'Verificato'
        : (v == null ? 'Non richiesta · necessaria per la vetrina' : v.statusLabel);
    return [
      if (!profile.professionalVerified)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Card(
            color: const Color(0xFFFFF7E6),
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.orange),
              title: const Text('Completa la verifica professionale'),
              subtitle: const Text('Serve per comparire nella vetrina, pubblicare ricette e verificare quelle dei pazienti.'),
              onTap: () => _open(const VerificationScreen()),
            ),
          ),
        ),
      MenuGroup(title: 'La tua vetrina', items: [
        MenuItem(
          icon: Icons.storefront_outlined,
          title: 'Profilo pubblico',
          subtitle: (_details?.isPublic ?? false) && profile.professionalVerified
              ? 'Visibile in "Trova un nutrizionista"'
              : 'Non visibile ai pazienti',
          onTap: () => _open(PublicProfileEditorScreen(profile: profile)),
        ),
        MenuItem(
          icon: Icons.assignment_outlined,
          title: 'Piani alimentari di base',
          subtitle: 'Proposte che attirano nuovi pazienti',
          onTap: () => _open(const PlanTemplatesScreen()),
        ),
        MenuItem(
          icon: Icons.menu_book_outlined,
          title: 'Ricette',
          subtitle: 'Le tue ricette e quelle da verificare',
          onTap: () => _open(const MyRecipesScreen(showReviewQueue: true)),
        ),
      ]),
      MenuGroup(title: 'Pazienti', items: [
        MenuItem(
          icon: Icons.person_add_alt,
          title: 'Invita pazienti',
          subtitle: 'Genera un codice invito',
          onTap: () => _open(const InvitationsScreen()),
        ),
        MenuItem(
          icon: Icons.verified_user_outlined,
          title: 'Verifica professionale',
          subtitle: verificationSubtitle,
          onTap: () => _open(const VerificationScreen()),
        ),
      ]),
    ];
  }
}
