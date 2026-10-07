import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/community_models.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../profile/profile_widgets.dart';

/// Una richiesta di abilitazione professionale, come la restituisce
/// `get_pending_verifications`.
class VerificationRequest {
  final String id;
  final String userId;
  final String displayName;
  final String profession;
  final String licenseBody;
  final String licenseNumber;

  /// `pending`, `verified` o `rejected`.
  final String status;
  final bool alreadyVerified;
  final DateTime? createdAt;

  const VerificationRequest({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.profession,
    required this.licenseBody,
    required this.licenseNumber,
    required this.status,
    required this.alreadyVerified,
    this.createdAt,
  });

  bool get isPending => status == 'pending';

  String get statusLabel => switch (status) {
        'verified' => 'Approvata',
        'rejected' => 'Rifiutata',
        _ => 'In attesa',
      };

  factory VerificationRequest.fromJson(Map<String, dynamic> json) => VerificationRequest(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        displayName: (json['display_name'] as String?) ?? 'Professionista',
        profession: (json['profession'] as String?) ?? 'nutritionist',
        licenseBody: (json['license_body'] as String?) ?? '',
        licenseNumber: (json['license_number'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'pending',
        alreadyVerified: (json['already_verified'] as bool?) ?? false,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

/// Verifiche professionali (migration 024). Solo per gli amministratori:
/// senza questa schermata l'unico modo di abilitare un professionista era
/// una UPDATE a mano sul database.
class AdminVerificationsScreen extends StatefulWidget {
  const AdminVerificationsScreen({super.key});

  @override
  State<AdminVerificationsScreen> createState() => _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState extends State<AdminVerificationsScreen> {
  List<VerificationRequest> _requests = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

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
      final rows = await withSessionRetry(() => supabase.rpc('get_pending_verifications')) as List;
      if (!mounted) return;
      setState(() {
        _requests = rows
            .map((r) => VerificationRequest.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList();
        _loading = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _review(VerificationRequest r, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Abilitare ${r.displayName}?' : 'Rifiutare ${r.displayName}?'),
        content: Text(approve
            ? 'Potrà comparire nella vetrina, pubblicare ricette e verificare quelle dei pazienti. '
                'Controlla che ${r.licenseBody} ${r.licenseNumber} corrisponda.'
            : 'Riceverà una notifica e potrà inviare di nuovo la richiesta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Abilita' : 'Rifiuta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = r.id);
    try {
      await withSessionRetry(() => supabase.rpc('review_professional_verification', params: {
            'p_id': r.id,
            'p_approve': approve,
          }));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? '${r.displayName} è abilitato.' : 'Richiesta rifiutata.')),
      );
      _load();
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return SettingsPage(
      title: 'Verifiche professionali',
      busy: _loading,
      children: [
        if (_error != null)
          SectionCard(
            title: 'Elenco non disponibile',
            subtitle: _error,
            children: [TextButton(onPressed: _load, child: const Text('Riprova'))],
          )
        else if (_requests.isEmpty && !_loading)
          SectionCard(
            title: 'Nessuna richiesta',
            subtitle: 'Qui arrivano le richieste di abilitazione inviate dai professionisti.',
            children: const [],
          )
        else
          for (final r in _requests)
            SectionCard(
              title: r.displayName,
              subtitle: '${professionLabels[r.profession] ?? 'Nutrizionista'} · ${r.licenseBody} ${r.licenseNumber}',
              children: [
                Row(children: [
                  Icon(
                    r.status == 'verified'
                        ? Icons.verified
                        : r.status == 'rejected'
                            ? Icons.block
                            : Icons.hourglass_empty,
                    size: 16,
                    color: r.status == 'verified' ? primaryTeal : textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(r.statusLabel, style: TextStyle(color: textSecondary, fontSize: 13)),
                  if (r.createdAt != null)
                    Text(
                      ' · ${r.createdAt!.day}/${r.createdAt!.month}/${r.createdAt!.year}',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                ]),
                if (r.status == 'verified' && !r.alreadyVerified)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Attenzione: la richiesta è approvata ma il profilo non risulta abilitato. '
                      'Approva di nuovo per allineare i due valori.',
                      style: TextStyle(color: colorG, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_busyId == r.id)
                  Center(child: CircularProgressIndicator(color: primaryTeal))
                else
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _review(r, false),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Rifiuta'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _review(r, true),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(r.isPending ? 'Abilita' : 'Riabilita'),
                      ),
                    ),
                  ]),
              ],
            ),
      ],
    );
  }
}

