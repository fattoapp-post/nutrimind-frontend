import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/app_error.dart';
import '../../core/chat_service.dart';
import '../../core/models.dart';
import '../../core/nutritionist_service.dart';
import '../../core/recipe_service.dart';
import '../chat/chat_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/invitations_screen.dart';
import '../profile/verification_screen.dart';
import '../shell/nutritionist_shell.dart';
import '../shell/patient_shell.dart';
import 'create_food_screen.dart';
import 'patient_detail_screen.dart';

/// Home del nutrizionista: pazienti collegati ordinati per attenzione.
class PatientsScreen extends StatefulWidget {
  final Profile profile;

  const PatientsScreen({super.key, required this.profile});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> with ReloadOnTabVisible {

  List<PatientOverview> _patients = [];
  int _toReview = 0;
  bool _loading = true;
  String? _error;

  @override
  int get tabIndex => NutritionistTab.patients;

  @override
  void onTabVisible() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _patients.isEmpty;
      _error = null;
    });
    try {
      final patients = await NutritionistService.getMyPatients();
      var toReview = 0;
      try {
        toReview = (await RecipeService.getToReview()).length;
      } on AppError {
        // contatore secondario
      }
      if (mounted) {
        setState(() {
          _patients = patients;
          _toReview = toReview;
        });
      }
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    final verified = widget.profile.professionalVerified;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('I tuoi pazienti', style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(
              widget.profile.displayName.isEmpty ? 'Portale nutrizionista' : widget.profile.displayName,
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifiche',
            icon: Icon(Icons.notifications_outlined, color: textPrimary),
            onPressed: () => _push(const NotificationsScreen()),
          ),
          IconButton(
            tooltip: 'Invita un paziente',
            icon: Icon(Icons.person_add_alt, color: textPrimary),
            onPressed: () => _push(const InvitationsScreen()),
          ),
        ],
      ),
      floatingActionButton: verified
          ? FloatingActionButton.extended(
              onPressed: () => _push(const CreateFoodScreen()),
              backgroundColor: primaryTeal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nuovo alimento', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!verified)
              Card(
                color: warningBg,
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: warningFg),
                  title: const Text('Profilo non ancora verificato'),
                  subtitle: const Text('Richiedi la verifica per comparire in vetrina, pubblicare ricette e creare alimenti.'),
                  onTap: () => _push(const VerificationScreen()),
                ),
              ),
            if (!_loading && _error == null) _buildStats(),
            if (_loading)
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: primaryTeal)),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(children: [
                  Text(_error!, style: TextStyle(color: textSecondary)),
                  TextButton(onPressed: _load, child: Text('Riprova', style: TextStyle(color: primaryTeal))),
                ]),
              )
            else if (_patients.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: Text(
                  'Nessun paziente collegato.\nGenera un codice invito con l\'icona in alto, oppure rendi pubblico '
                  'il tuo profilo: i pazienti potranno trovarti e scriverti.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary),
                ),
              )
            else
              for (final p in _patients) _buildPatientCard(p),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(PatientOverview p) {
    final attention = p.attentionScore >= 50;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: attention ? warningFg : borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: primaryTeal.withValues(alpha: 0.12),
          child: Text(
            p.displayName.isEmpty ? '?' : p.displayName[0].toUpperCase(),
            style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(p.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
        subtitle: Text(
          p.sharesAdherence
              ? 'Ultimi 7 giorni: ${p.daysLoggedLast7} registrati · ${p.daysOnTargetLast7} in target'
              : 'Il paziente non condivide l\'aderenza',
          style: TextStyle(color: textSecondary),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (attention) Icon(Icons.priority_high, color: warningFg),
          IconButton(
            tooltip: 'Scrivi',
            icon: Icon(Icons.chat_bubble_outline, color: primaryTeal),
            onPressed: () => _openChat(p),
          ),
        ]),
        onTap: () => _push(PatientDetailScreen(patient: p)),
      ),
    );
  }

  Future<void> _openChat(PatientOverview p) async {
    try {
      final id = await ChatService.start(p.patientId);
      if (!mounted) return;
      _push(ChatScreen(conversationId: id, otherName: p.displayName, iAmNutritionist: true, linked: true));
    } on AppError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _buildStats() {
    final attention = _patients.where((p) => p.attentionScore >= 50).length;
    Widget stat(String value, String label, IconData icon, {VoidCallback? onTap}) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(children: [
                Icon(icon, color: primaryTeal),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSecondary)),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        stat('${_patients.length}', 'Pazienti', Icons.groups_outlined),
        const SizedBox(width: 8),
        stat('$attention', 'Da seguire', Icons.priority_high),
        const SizedBox(width: 8),
        stat('$_toReview', 'Ricette da verificare', Icons.rate_review_outlined,
            onTap: () => PatientShellScope.maybeOf(context)?.value = NutritionistTab.recipes),
      ]),
    );
  }
}
