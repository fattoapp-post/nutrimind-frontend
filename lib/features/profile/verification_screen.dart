import 'package:flutter/material.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/models.dart';
import 'profile_widgets.dart';

/// Nutrizionista: richiesta e stato della verifica professionale.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _body = TextEditingController();
  final _number = TextEditingController();
  ProfessionalVerification? _verification;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_body, _number]) {
      c.addListener(() => setState(() {}));
    }
    _load();
  }

  @override
  void dispose() {
    _body.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final v = await AccountService.getLatestVerification();
      if (mounted) setState(() => _verification = v);
    } on AppError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    final ok = await runWithFeedback(
      context,
      () => AccountService.requestVerification(licenseBody: _body.text.trim(), licenseNumber: _number.text.trim()),
      success: 'Richiesta inviata: ti avviseremo quando sarà verificata.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final v = _verification;
    final canRequest = v == null || v.status == 'rejected';
    return SettingsPage(
      title: 'Verifica professionale',
      busy: _loading || _busy,
      children: [
        const SectionCard(
          title: 'Perché verificarsi',
          children: [
            Text('• Comparire nella vetrina "Trova un nutrizionista"\n'
                '• Pubblicare ricette per i pazienti\n'
                '• Verificare le ricette dei tuoi pazienti\n'
                '• Inserire alimenti e porzioni nel catalogo'),
          ],
        ),
        if (v != null)
          SectionCard(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                v.status == 'verified' ? Icons.verified : (v.status == 'rejected' ? Icons.cancel_outlined : Icons.hourglass_top),
                color: v.status == 'rejected' ? Colors.red : ProfilePalette.teal,
              ),
              title: Text(v.statusLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${v.licenseBody} · n. ${v.licenseNumber}'),
            ),
          ]),
        if (canRequest)
          SectionCard(
            title: v == null ? 'Richiedi la verifica' : 'Invia una nuova richiesta',
            children: [
              TextField(controller: _body, decoration: const InputDecoration(labelText: 'Ordine o albo', hintText: 'Es. Ordine dei Biologi del Lazio')),
              TextField(controller: _number, decoration: const InputDecoration(labelText: 'Numero di iscrizione')),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _busy || _body.text.trim().isEmpty || _number.text.trim().isEmpty ? null : _request,
                  child: const Text('Invia richiesta'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
