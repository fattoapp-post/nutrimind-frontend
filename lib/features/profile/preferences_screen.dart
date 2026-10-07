import 'package:flutter/material.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/models.dart';
import 'profile_widgets.dart';

/// Paziente: restrizioni alimentari e promemoria di registrazione.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  PatientSettings? _settings;
  Set<String> _restrictions = {};
  bool _reminders = true;
  int _reminderHours = 24;
  bool _loading = true;
  bool _busy = false;
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
      final s = await AccountService.getPatientSettings();
      if (!mounted) return;
      setState(() {
        _settings = s;
        _restrictions = {...?s?.dietaryRestrictions};
        _reminders = s?.remindersEnabled ?? true;
        _reminderHours = const [12, 24, 48, 72].contains(s?.reminderAfterHours) ? s!.reminderAfterHours : 24;
      });
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runWithFeedback(
      context,
      () => AccountService.updatePatientSettings(PatientSettings(
        dietaryRestrictions: _restrictions.toList(),
        timezone: _settings?.timezone ?? 'Europe/Rome',
        remindersEnabled: _reminders,
        reminderAfterHours: _reminderHours,
      )),
      success: 'Preferenze salvate.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return SettingsPage(title: 'Alimentazione', busy: _loading, children: [
        if (_error != null)
          Center(
            child: Column(children: [
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Riprova')),
            ]),
          ),
      ]);
    }
    return SettingsPage(
      title: 'Alimentazione',
      busy: _busy,
      bottom: FilledButton(onPressed: _busy ? null : _save, child: const Text('Salva preferenze')),
      children: [
        SectionCard(
          title: 'Restrizioni e scelte alimentari',
          subtitle: 'Le usiamo per filtrare ricette e suggerimenti. Il nutrizionista le vede solo se condividi il consenso "Restrizioni alimentari".',
          children: [
            TagSelector(
              options: dietaryRestrictionLabels,
              selected: _restrictions,
              onChanged: (v) => setState(() => _restrictions = v),
            ),
          ],
        ),
        SectionCard(
          title: 'Promemoria',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ricordami di registrare i pasti'),
              value: _reminders,
              activeThumbColor: ProfilePalette.teal,
              onChanged: (v) => setState(() => _reminders = v),
            ),
            if (_reminders)
              DropdownButtonFormField<int>(
                initialValue: _reminderHours,
                decoration: const InputDecoration(labelText: 'Avvisami dopo'),
                items: const [
                  DropdownMenuItem(value: 12, child: Text('12 ore senza registrazioni')),
                  DropdownMenuItem(value: 24, child: Text('24 ore senza registrazioni')),
                  DropdownMenuItem(value: 48, child: Text('48 ore senza registrazioni')),
                  DropdownMenuItem(value: 72, child: Text('72 ore senza registrazioni')),
                ],
                onChanged: (v) => setState(() => _reminderHours = v ?? 24),
              ),
          ],
        ),
      ],
    );
  }
}
