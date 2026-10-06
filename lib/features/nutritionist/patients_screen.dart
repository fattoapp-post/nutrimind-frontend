import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/models.dart';
import '../../core/nutritionist_service.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import 'create_food_screen.dart';
import 'patient_detail_screen.dart';

/// Home del nutrizionista: pazienti collegati ordinati per attenzione.
class PatientsScreen extends StatefulWidget {
  final Profile profile;

  const PatientsScreen({super.key, required this.profile});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  List<PatientOverview> _patients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final patients = await NutritionistService.getMyPatients();
      if (mounted) setState(() => _patients = patients);
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
    final verified = widget.profile.professionalVerified;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('I tuoi pazienti', style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(
              widget.profile.displayName.isEmpty ? 'Portale nutrizionista' : widget.profile.displayName,
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifiche',
            icon: const Icon(Icons.notifications_outlined, color: textPrimary),
            onPressed: () => _push(const NotificationsScreen()),
          ),
          IconButton(
            tooltip: 'Profilo',
            icon: const Icon(Icons.person_outline, color: textPrimary),
            onPressed: () => _push(const ProfileScreen(showBottomNav: false)),
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
                color: const Color(0xFFFFF7E6),
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.orange),
                  title: const Text('Profilo non ancora verificato'),
                  subtitle: const Text('Richiedi la verifica dal profilo per creare alimenti e porzioni.'),
                  onTap: () => _push(const ProfileScreen(showBottomNav: false)),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: primaryTeal)),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(children: [
                  Text(_error!, style: const TextStyle(color: textSecondary)),
                  TextButton(onPressed: _load, child: const Text('Riprova', style: TextStyle(color: primaryTeal))),
                ]),
              )
            else if (_patients.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Text(
                  'Nessun paziente collegato.\nGenera un codice invito dal profilo e condividilo.',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: attention ? Colors.orange.shade200 : Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: primaryTeal.withValues(alpha: 0.12),
          child: Text(
            p.displayName.isEmpty ? '?' : p.displayName[0].toUpperCase(),
            style: const TextStyle(color: primaryTeal, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
        subtitle: Text(
          p.sharesAdherence
              ? 'Ultimi 7 giorni: ${p.daysLoggedLast7} registrati · ${p.daysOnTargetLast7} in target'
              : 'Il paziente non condivide l\'aderenza',
          style: const TextStyle(color: textSecondary),
        ),
        trailing: attention ? const Icon(Icons.priority_high, color: Colors.orange) : const Icon(Icons.chevron_right),
        onTap: () => _push(PatientDetailScreen(patient: p)),
      ),
    );
  }
}
