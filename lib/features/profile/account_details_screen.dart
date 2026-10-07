import 'package:flutter/material.dart';

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
