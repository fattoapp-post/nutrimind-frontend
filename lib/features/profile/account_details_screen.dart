import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_error.dart';

import '../../core/theme.dart';

import '../../core/account_service.dart';
import '../../core/models.dart';
import 'profile_widgets.dart';

/// Dati dell'account: nome visualizzato, lingua, email, password.
class AccountDetailsScreen extends StatefulWidget {
  final Profile profile;

  const AccountDetailsScreen({super.key, required this.profile});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  late final _name = TextEditingController(text: widget.profile.displayName);
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  late String _locale = widget.profile.locale == 'en' ? 'en' : 'it';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final ok = await runWithFeedback(
      context,
      () => AccountService.updateProfile(displayName: name, locale: _locale),
      success: 'Dati aggiornati.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _changePassword() async {
    final p = _password.text;
    if (p.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La password deve avere almeno 8 caratteri.')));
      return;
    }
    if (p != _passwordConfirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le due password non coincidono.')));
      return;
    }
    setState(() => _busy = true);
    final ok = await runWithFeedback(context, () => AccountService.changePassword(p), success: 'Password aggiornata.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _password.clear();
      _passwordConfirm.clear();
    }
  }


  /// Esportazione: il risultato finisce negli appunti. Non si salva un
  /// file perché servirebbe un pacchetto per ogni piattaforma; il
  /// contenuto però è completo, ed è quello che conta per la richiesta.
  Future<void> _exportData() async {
    setState(() => _busy = true);
    try {
      final data = await AccountService.exportMyData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      final righe = data.entries
          .where((e) => e.value is List)
          .fold<int>(0, (s, e) => s + (e.value as List).length);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copiati negli appunti $righe elementi '
              '(${(json.length / 1024).toStringAsFixed(1)} KB). Incollali in un file .json.'),
          duration: const Duration(seconds: 6),
        ),
      );
    } on AppError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Due conferme, la seconda da scrivere a mano: cancellare e' definitivo
  /// e non c'e' modo di tornare indietro.
  Future<void> _deleteAccount() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare il tuo account?'),
        content: const Text(
          'Spariscono utenza, diario, piani, preferiti, ricette e messaggi. '
          'Non si può annullare.\n\n'
          'Se vuoi solo una copia dei dati, usa prima "Esporta i miei dati".',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continua')),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Scrivi ELIMINA per procedere.'),
          const SizedBox(height: 12),
          TextField(controller: controller, autofocus: true, decoration: const InputDecoration(isDense: true)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, controller.text.trim().toUpperCase() == 'ELIMINA'),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AccountService.deleteMyAccount();
      await AccountService.signOut();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return SettingsPage(
      title: 'Dati personali',
      busy: _busy,
      bottom: FilledButton(onPressed: _busy ? null : _save, child: const Text('Salva')),
      children: [
        SectionCard(
          children: [
            TextField(controller: _name, maxLength: 80, decoration: const InputDecoration(labelText: 'Nome visualizzato')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.alternate_email, color: ProfilePalette.textSecondary),
              title: Text(AccountService.email ?? '—'),
              subtitle: const Text('Email di accesso'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _locale,
              decoration: const InputDecoration(labelText: 'Lingua'),
              items: const [
                DropdownMenuItem(value: 'it', child: Text('Italiano')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) => setState(() => _locale = v ?? 'it'),
            ),
          ],
        ),
        SectionCard(
          title: 'I tuoi dati',
          subtitle: 'Trattiamo dati alimentari: hai diritto a riaverli e a cancellarli.',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.download_outlined, color: ProfilePalette.teal),
              title: const Text('Esporta i miei dati'),
              subtitle: const Text('Diario, piani, ricette, consensi e registro, in formato JSON'),
              onTap: _busy ? null : _exportData,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const Text('Elimina il mio account'),
              subtitle: const Text('Definitivo: spariscono utenza, diario e tutto il resto'),
              onTap: _busy ? null : _deleteAccount,
            ),
          ],
        ),
        SectionCard(
          title: 'Cambia password',
          children: [
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Nuova password')),
            TextField(controller: _passwordConfirm, obscureText: true, decoration: const InputDecoration(labelText: 'Ripeti la password')),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(onPressed: _busy ? null : _changePassword, child: const Text('Aggiorna password')),
            ),
          ],
        ),
      ],
    );
  }
}
