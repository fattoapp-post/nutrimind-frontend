import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/models.dart';
import '../../core/widgets/custom_bottom_nav.dart';
import '../auth/auth_gate.dart';

/// Profilo dell'utente. Per i pazienti: impostazioni, collegamento al
/// nutrizionista e consensi. Per i nutrizionisti: dettagli studio,
/// verifica professionale e codici invito.
class ProfileScreen extends StatefulWidget {
  /// Mostra la barra di navigazione del paziente.
  final bool showBottomNav;

  const ProfileScreen({super.key, this.showBottomNav = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  final _name = TextEditingController();
  final _studio = TextEditingController();
  final _bio = TextEditingController();
  final _licenseBody = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _inviteCode = TextEditingController();

  Profile? _profile;
  PatientSettings? _settings;
  ProfessionalVerification? _verification;
  List<PatientLink> _links = [];
  Invitation? _invitation;
  Set<ConsentScope> _redeemScopes = {ConsentScope.adherence};

  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // I pulsanti si abilitano solo con i campi compilati
    for (final c in [_name, _licenseBody, _licenseNumber, _inviteCode]) {
      c.addListener(_onFieldChanged);
    }
    _load();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_name, _studio, _bio, _licenseBody, _licenseNumber, _inviteCode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await AccountService.getProfile();
      _profile = profile;
      _name.text = profile.displayName;
      if (profile.isNutritionist) {
        final details = await AccountService.getNutritionistDetails();
        _studio.text = details?.studioName ?? '';
        _bio.text = details?.bio ?? '';
        _verification = await AccountService.getLatestVerification();
      } else {
        _settings = await AccountService.getPatientSettings();
      }
      _links = await AccountService.getMyLinks();
    } on AppError catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Esegue un'azione mostrando l'esito; i campi restano compilati se fallisce.
  Future<void> _run(Future<void> Function() action, {String? success, bool reload = false}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (success != null) _snack(success);
      if (reload) await _load();
    } on AppError catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text('Profilo', style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Esci',
            icon: const Icon(Icons.logout, color: textPrimary),
            onPressed: _busy ? null : _confirmSignOut,
          ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav ? const CustomBottomNav(currentIndex: 3, isDarkMode: false) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryTeal))
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: textSecondary)),
                    TextButton(onPressed: _load, child: const Text('Riprova', style: TextStyle(color: primaryTeal))),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_busy) const LinearProgressIndicator(color: primaryTeal),
                      _buildAccountCard(),
                      const SizedBox(height: 16),
                      if (_profile!.isNutritionist) ...[
                        _buildNutritionistCard(),
                        const SizedBox(height: 16),
                        _buildVerificationCard(),
                        const SizedBox(height: 16),
                        _buildInvitationCard(),
                      ] else ...[
                        _buildSettingsCard(),
                        const SizedBox(height: 16),
                        _buildPatientLinksCard(),
                      ],
                    ],
                  ),
                ),
    );
  }

  // --- Account ------------------------------------------------------------

  Widget _buildAccountCard() {
    final profile = _profile!;
    return _card(
      title: 'Account',
      children: [
        Row(children: [
          Chip(label: Text(profile.isNutritionist ? 'Nutrizionista' : 'Paziente')),
          const SizedBox(width: 8),
          if (profile.isNutritionist)
            Chip(
              avatar: Icon(profile.professionalVerified ? Icons.verified : Icons.hourglass_empty, size: 16, color: primaryTeal),
              label: Text(profile.professionalVerified ? 'Verificato' : 'Non verificato'),
            ),
        ]),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome visualizzato'), maxLength: 80),
        DropdownButtonFormField<String>(
          initialValue: profile.locale == 'en' ? 'en' : 'it',
          decoration: const InputDecoration(labelText: 'Lingua'),
          items: const [
            DropdownMenuItem(value: 'it', child: Text('Italiano')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: _busy
              ? null
              : (v) => _run(() => AccountService.updateProfile(locale: v), success: 'Lingua aggiornata.', reload: true),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy || _name.text.trim().isEmpty
                ? null
                : () => _run(() => AccountService.updateProfile(displayName: _name.text.trim()), success: 'Profilo aggiornato.'),
            child: const Text('Salva'),
          ),
        ),
      ],
    );
  }

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
    // La bottom nav usa pushReplacement, quindi AuthGate potrebbe non essere
    // più nello stack: si riparte da lì, che mostrerà il login.
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false);
    }
  }

  // --- Paziente -----------------------------------------------------------

  Widget _buildSettingsCard() {
    final s = _settings;
    if (s == null) {
      return _card(title: 'Preferenze', children: const [Text('Impostazioni non disponibili.')]);
    }
    return _card(
      title: 'Preferenze',
      children: [
        const Text('Restrizioni alimentari', style: TextStyle(color: textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in dietaryRestrictionLabels.entries)
              FilterChip(
                label: Text(e.value),
                selected: s.dietaryRestrictions.contains(e.key),
                selectedColor: primaryTeal.withValues(alpha: 0.15),
                onSelected: _busy
                    ? null
                    : (on) => setState(() => _settings = PatientSettings(
                          dietaryRestrictions: on
                              ? [...s.dietaryRestrictions, e.key]
                              : s.dietaryRestrictions.where((r) => r != e.key).toList(),
                          timezone: s.timezone,
                          remindersEnabled: s.remindersEnabled,
                          reminderAfterHours: s.reminderAfterHours,
                        )),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Promemoria registrazione pasti'),
          value: s.remindersEnabled,
          activeThumbColor: primaryTeal,
          onChanged: _busy
              ? null
              : (v) => setState(() => _settings = PatientSettings(
                    dietaryRestrictions: s.dietaryRestrictions,
                    timezone: s.timezone,
                    remindersEnabled: v,
                    reminderAfterHours: s.reminderAfterHours,
                  )),
        ),
        if (s.remindersEnabled)
          DropdownButtonFormField<int>(
            initialValue: const [12, 24, 48, 72].contains(s.reminderAfterHours) ? s.reminderAfterHours : 24,
            decoration: const InputDecoration(labelText: 'Avvisami dopo'),
            items: const [
              DropdownMenuItem(value: 12, child: Text('12 ore senza registrazioni')),
              DropdownMenuItem(value: 24, child: Text('24 ore senza registrazioni')),
              DropdownMenuItem(value: 48, child: Text('48 ore senza registrazioni')),
              DropdownMenuItem(value: 72, child: Text('72 ore senza registrazioni')),
            ],
            onChanged: (v) => setState(() => _settings = PatientSettings(
                  dietaryRestrictions: s.dietaryRestrictions,
                  timezone: s.timezone,
                  remindersEnabled: s.remindersEnabled,
                  reminderAfterHours: v ?? 24,
                )),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() => AccountService.updatePatientSettings(_settings!), success: 'Preferenze salvate.'),
            child: const Text('Salva preferenze'),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientLinksCard() {
    return _card(
      title: 'Il tuo nutrizionista',
      children: [
        if (_links.isEmpty) ...[
          const Text('Inserisci il codice invito ricevuto dal tuo nutrizionista.', style: TextStyle(color: textSecondary)),
          TextField(
            controller: _inviteCode,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Codice invito'),
          ),
          const SizedBox(height: 12),
          const Text('Cosa condividi', style: TextStyle(color: textSecondary)),
          for (final scope in ConsentScope.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(scope.label),
              value: _redeemScopes.contains(scope),
              activeColor: primaryTeal,
              onChanged: (on) => setState(() {
                _redeemScopes = {..._redeemScopes};
                on == true ? _redeemScopes.add(scope) : _redeemScopes.remove(scope);
              }),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy || _inviteCode.text.trim().isEmpty
                  ? null
                  : () => _run(
                        () async {
                          await AccountService.redeemInvitation(_inviteCode.text, _redeemScopes);
                          _inviteCode.clear();
                        },
                        success: 'Collegamento creato.',
                        reload: true,
                      ),
              child: const Text('Collegati'),
            ),
          ),
        ],
        for (final link in _links) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.health_and_safety_outlined, color: primaryTeal),
            title: const Text('Nutrizionista collegato'),
            subtitle: link.createdAt == null ? null : Text('Dal ${_formatDate(link.createdAt!)}'),
            trailing: TextButton(
              onPressed: _busy ? null : () => _confirmRevokeLink(link),
              child: const Text('Scollega', style: TextStyle(color: Colors.red)),
            ),
          ),
          const Text('Consensi (puoi revocarli in qualsiasi momento)', style: TextStyle(color: textSecondary)),
          for (final scope in ConsentScope.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(scope.label),
              value: link.activeScopes.contains(scope),
              activeThumbColor: primaryTeal,
              onChanged: _busy
                  ? null
                  : (on) => _run(
                        () => on ? AccountService.grantConsent(link.id, scope) : AccountService.revokeConsent(link.id, scope),
                        success: on ? 'Consenso concesso.' : 'Consenso revocato.',
                        reload: true,
                      ),
            ),
        ],
      ],
    );
  }

  Future<void> _confirmRevokeLink(PatientLink link) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Interrompere il collegamento?'),
        content: const Text('Il nutrizionista non potrà più vedere i tuoi dati.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Scollega')),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => AccountService.revokeLink(link.id), success: 'Collegamento interrotto.', reload: true);
    }
  }

  // --- Nutrizionista --------------------------------------------------------

  Widget _buildNutritionistCard() {
    return _card(
      title: 'Studio',
      children: [
        TextField(controller: _studio, decoration: const InputDecoration(labelText: 'Nome studio')),
        TextField(controller: _bio, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                      () => AccountService.updateNutritionistDetails(
                        studioName: _studio.text.trim().isEmpty ? null : _studio.text.trim(),
                        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
                      ),
                      success: 'Dettagli salvati.',
                    ),
            child: const Text('Salva'),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationCard() {
    final v = _verification;
    final canRequest = v == null || v.status == 'rejected';
    return _card(
      title: 'Verifica professionale',
      children: [
        if (v != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              v.status == 'verified' ? Icons.verified : (v.status == 'rejected' ? Icons.cancel_outlined : Icons.hourglass_top),
              color: v.status == 'rejected' ? Colors.red : primaryTeal,
            ),
            title: Text(v.statusLabel),
            subtitle: Text('${v.licenseBody} · n. ${v.licenseNumber}'),
          ),
        if (canRequest) ...[
          const Text(
            'Senza verifica non puoi creare alimenti né porzioni nel catalogo.',
            style: TextStyle(color: textSecondary),
          ),
          TextField(controller: _licenseBody, decoration: const InputDecoration(labelText: 'Ordine / albo (es. Ordine dei Biologi del Lazio)')),
          TextField(controller: _licenseNumber, decoration: const InputDecoration(labelText: 'Numero iscrizione')),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy || _licenseBody.text.trim().isEmpty || _licenseNumber.text.trim().isEmpty
                  ? null
                  : () => _run(
                        () => AccountService.requestVerification(
                          licenseBody: _licenseBody.text.trim(),
                          licenseNumber: _licenseNumber.text.trim(),
                        ),
                        success: 'Richiesta inviata.',
                        reload: true,
                      ),
              child: const Text('Richiedi verifica'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInvitationCard() {
    final inv = _invitation;
    return _card(
      title: 'Invita un paziente',
      children: [
        const Text('Genera un codice e condividilo con il paziente. Vale 7 giorni.', style: TextStyle(color: textSecondary)),
        if (inv != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: SelectableText(inv.code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            subtitle: inv.expiresAt == null ? null : Text('Scade il ${_formatDate(inv.expiresAt!)}'),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inv.code));
                _snack('Codice copiato.');
              },
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      final created = await AccountService.createInvitation();
                      if (mounted) setState(() => _invitation = created);
                    }),
            icon: const Icon(Icons.add),
            label: const Text('Genera codice'),
          ),
        ),
      ],
    );
  }

  // --- Helper ---------------------------------------------------------------

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }
}
