import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/food_service.dart';
import '../../core/models.dart';
import '../../core/widgets/custom_bottom_nav.dart';
import '../shell/patient_shell.dart';

/// Andamento del paziente: aderenza al piano, serie di giorni registrati e
/// kcal giorno per giorno rispetto all'obiettivo.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with ReloadOnTabVisible {
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color primaryTeal = Color(0xFF127B6D);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color colorP = Color(0xFF5A44F2);
  static const Color colorC = Color(0xFFF0A500);
  static const Color colorG = Color(0xFFEB5A0C);

  int _rangeDays = 7;
  AdherenceSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  int get tabIndex => PatientTab.progress;

  @override
  void onTabVisible() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final range = _rangeDays;
    final to = DateUtils.dateOnly(DateTime.now());
    final from = to.subtract(Duration(days: range - 1));
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await FoodService.getMyAdherence(from, to);
      if (mounted && range == _rangeDays) setState(() => _summary = summary);
    } on AppError catch (e) {
      if (mounted && range == _rangeDays) setState(() => _error = e.message);
    } finally {
      if (mounted && range == _rangeDays) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progressi', style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Come stai seguendo il piano', style: TextStyle(color: textSecondary, fontSize: 14)),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: PatientTab.progress, isDarkMode: false),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 giorni')),
                ButtonSegment(value: 30, label: Text('30 giorni')),
              ],
              selected: {_rangeDays},
              onSelectionChanged: (v) {
                setState(() => _rangeDays = v.first);
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(color: primaryTeal),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: textSecondary)),
                  TextButton(onPressed: _load, child: const Text('Riprova', style: TextStyle(color: primaryTeal))),
                ]),
              ),
            if (s != null) ...[
              _buildStats(s),
              const SizedBox(height: 16),
              if (s.planDays == 0)
                _card(
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: primaryTeal),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nessun piano macro attivo nel periodo: l\'aderenza si calcola quando il nutrizionista ti assegna un piano.',
                        style: TextStyle(color: textPrimary),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 16),
              _buildKcalChart(s),
              const SizedBox(height: 16),
              _buildMacroAverages(s),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats(AdherenceSummary s) {
    Widget stat(String value, String label, IconData icon) => Expanded(
          child: _card(
            child: Column(children: [
              Icon(icon, color: primaryTeal),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: textSecondary)),
            ]),
          ),
        );
    return Row(children: [
      stat(s.planDays == 0 ? '—' : '${s.adherenceRate}%', 'Aderenza', Icons.track_changes),
      const SizedBox(width: 8),
      stat('${s.loggedDays}/${s.totalDays}', 'Giorni registrati', Icons.event_available),
      const SizedBox(width: 8),
      stat('${s.loggingStreak}', 'Giorni di fila', Icons.local_fire_department_outlined),
    ]);
  }

  /// Barre kcal per giorno; la linea indica l'obiettivo.
  Widget _buildKcalChart(AdherenceSummary s) {
    final maxValue = s.days.fold<double>(1, (m, d) => [m, d.kcal, d.targetKcal].reduce((a, b) => a > b ? a : b));
    const short = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calorie per giorno', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          Text('Media nei giorni registrati: ${s.averageKcalLogged.round()} kcal', style: const TextStyle(color: textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in s.days)
                  Expanded(
                    child: Tooltip(
                      message: '${d.date.day}/${d.date.month}: ${d.kcal.round()} kcal'
                          '${d.hasPlan ? ' / ${d.targetKcal.round()}' : ''}',
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: s.days.length > 10 ? 1 : 4),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            FractionallySizedBox(
                              heightFactor: (d.kcal / maxValue).clamp(0.02, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !d.logged
                                      ? Colors.grey.shade300
                                      : (d.onTarget == true ? primaryTeal : primaryTeal.withValues(alpha: 0.45)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            if (d.hasPlan)
                              Align(
                                alignment: Alignment(0, 1 - 2 * (d.targetKcal / maxValue).clamp(0.0, 1.0)),
                                child: Container(height: 2, color: colorC),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (s.days.length <= 10) ...[
            const SizedBox(height: 6),
            Row(children: [
              for (final d in s.days)
                Expanded(
                  child: Text(
                    short[d.date.weekday - 1],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
            ]),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 4, children: [
            _legend(primaryTeal, 'In target'),
            _legend(primaryTeal.withValues(alpha: 0.45), 'Fuori target'),
            _legend(Colors.grey.shade300, 'Non registrato'),
            _legend(colorC, 'Obiettivo', line: true),
          ]),
        ],
      ),
    );
  }

  Widget _buildMacroAverages(AdherenceSummary s) {
    final logged = s.days.where((d) => d.logged).toList();
    double avg(double Function(AdherenceDay d) f) =>
        logged.isEmpty ? 0 : logged.fold(0.0, (sum, d) => sum + f(d)) / logged.length;
    final planned = s.days.where((d) => d.hasPlan).toList();
    double avgTarget(double Function(AdherenceDay d) f) =>
        planned.isEmpty ? 0 : planned.fold(0.0, (sum, d) => sum + f(d)) / planned.length;

    Widget row(String label, Color color, double value, double target) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
              target > 0 ? '${value.round()} / ${target.round()} g' : '${value.round()} g',
              style: const TextStyle(color: textPrimary),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: target > 0 ? (value / target).clamp(0.0, 1.0) : 0,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ]),
      );
    }

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Media giornaliera dei macro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
        if (logged.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Registra i tuoi pasti per vedere le medie.', style: TextStyle(color: textSecondary)),
          )
        else ...[
          row('Proteine', colorP, avg((d) => d.protein), avgTarget((d) => d.targetProtein)),
          row('Carboidrati', colorC, avg((d) => d.carbs), avgTarget((d) => d.targetCarbs)),
          row('Grassi', colorG, avg((d) => d.fat), avgTarget((d) => d.targetFat)),
        ],
      ]),
    );
  }

  Widget _legend(Color color, String label, {bool line = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: line ? 2 : 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
      ]);

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: child,
      );
}
