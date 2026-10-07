import 'package:flutter/material.dart';

import '../../core/admin_service.dart';
import '../../core/app_error.dart';
import '../../core/theme.dart';
import '../profile/profile_widgets.dart';
import '../recipes/my_recipes_screen.dart';
import 'foods_to_review_screen.dart';
import 'verifications_screen.dart';

/// Quadro di chi amministra. Prima l'unico modo di sapere se c'era
/// qualcosa da fare era aprire le code una per una.
///
/// In cima stanno le decisioni in attesa, perché sono l'unica cosa che
/// blocca qualcun altro: un professionista non abilitato non può
/// lavorare, un alimento non verificato resta inutilizzabile nelle
/// ricette, una ricetta in attesa non arriva ai pazienti.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  AdminOverview? _overview;
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
      final overview = await AdminService.getOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
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

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    final o = _overview;
    return SettingsPage(
      title: 'Amministrazione',
      busy: _loading,
      children: [
        if (_error != null)
          SectionCard(
            title: 'Numeri non disponibili',
            subtitle: _error,
            children: [TextButton(onPressed: _load, child: const Text('Riprova'))],
          ),
        if (o != null) ...[
          SectionCard(
            title: o.pendingTotal == 0 ? 'Niente in attesa' : 'Da decidere: ${o.pendingTotal}',
            subtitle: o.pendingTotal == 0
                ? 'Nessuna richiesta aperta. Il resto sono numeri di contesto.'
                : 'Finché restano in attesa, qualcuno è bloccato.',
            children: [
              _queue(
                icon: Icons.verified_user_outlined,
                label: 'Abilitazioni professionali',
                count: o.pendingVerifications,
                detail: 'Senza abilitazione non si pubblicano ricette né si compare in vetrina',
                onTap: () => _open(const AdminVerificationsScreen()),
              ),
              _queue(
                icon: Icons.restaurant,
                label: 'Alimenti da verificare',
                count: o.foodsToReview,
                detail: 'Un alimento non verificato resta inusabile nelle ricette',
                onTap: () => _open(const FoodsToReviewScreen()),
              ),
              _queue(
                icon: Icons.menu_book_outlined,
                label: 'Ricette da verificare',
                count: o.mealsToReview,
                detail: 'Proposte dai pazienti, in attesa di un professionista',
                onTap: () => _open(const MyRecipesScreen(showReviewQueue: true)),
              ),
            ],
          ),
          SectionCard(
            title: 'Persone',
            children: [
              _row('Pazienti', o.patients.toString()),
              _row('Professionisti', '${o.professionals} · ${o.verifiedProfessionals} abilitati'),
              _row('In vetrina', o.publicProfessionals.toString(),
                  hint: o.verifiedProfessionals > 0 && o.publicProfessionals == 0
                      ? 'Nessuno si è reso visibile: i pazienti non trovano nessuno da contattare'
                      : null),
              _row('Collegamenti attivi', o.activeLinks.toString()),
            ],
          ),
          SectionCard(
            title: 'Contenuti',
            children: [
              _row('Alimenti in catalogo', o.foodsTotal.toString(),
                  hint: o.foodsTotal < 100
                      ? 'Catalogo molto piccolo: ogni ricerca finisce sul catalogo esterno '
                          'e la ricerca per valori nutrizionali ha poco da filtrare'
                      : null),
              _row('Di cui verificati', o.foodsVerified.toString()),
              _row('Ricette pubblicate', o.recipesPublished.toString()),
              _row('Pasti registrati (7 giorni)', o.diaryEntriesLast7.toString()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _queue({
    required IconData icon,
    required String label,
    required int count,
    required String detail,
    required VoidCallback onTap,
  }) {
    final urgent = count > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: urgent ? warningBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: urgent ? warningFg : borderColor),
          ),
          child: Row(children: [
            Icon(icon, color: urgent ? warningFg : textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                Text(detail, style: TextStyle(color: textSecondary, fontSize: 11)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(count.toString(),
                style: TextStyle(
                  color: urgent ? warningFg : textSecondary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                )),
            Icon(Icons.chevron_right, color: textSecondary, size: 18),
          ]),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(color: textSecondary)),
                Text(value, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
              ],
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(hint, style: TextStyle(color: warningFg, fontSize: 11)),
              ),
          ],
        ),
      );
}
