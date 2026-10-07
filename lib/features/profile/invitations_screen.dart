import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/account_service.dart';
import '../../core/models.dart';
import 'profile_widgets.dart';

/// Nutrizionista: genera codici invito da dare ai pazienti.
class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  final List<Invitation> _created = [];
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    Invitation? invitation;
    await runWithFeedback(context, () async => invitation = await AccountService.createInvitation());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (invitation != null) _created.insert(0, invitation!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'Invita pazienti',
      busy: _busy,
      bottom: FilledButton.icon(onPressed: _busy ? null : _create, icon: const Icon(Icons.add), label: const Text('Genera codice')),
      children: [
        const SectionCard(
          title: 'Come funziona',
          children: [
            Text('1. Genera un codice (vale 7 giorni, un solo uso).\n'
                '2. Mandalo al paziente: di persona, via email o direttamente dalla chat con "Invia invito".\n'
                '3. Il paziente lo inserisce in Profilo → Il mio nutrizionista e sceglie cosa condividere.'),
          ],
        ),
        for (final inv in _created)
          SectionCard(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: SelectableText(inv.code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
              subtitle: inv.expiresAt == null
                  ? const Text('Valido 7 giorni')
                  : Text('Scade il ${inv.expiresAt!.day}/${inv.expiresAt!.month}/${inv.expiresAt!.year}'),
              trailing: IconButton(
                tooltip: 'Copia',
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inv.code));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Codice copiato.')));
                },
              ),
            ),
          ]),
      ],
    );
  }
}
