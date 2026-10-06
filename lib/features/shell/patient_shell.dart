import 'package:flutter/material.dart';

import '../auth/home_screen.dart';
import '../food/favorites_screen.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';

/// Area del paziente: le schede restano vive (IndexedStack) e la barra in
/// basso cambia scheda senza sostituire la route, così AuthGate resta alla
/// radice dello stack e logout/scadenza sessione riportano al login.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  final _tab = ValueNotifier<int>(PatientTab.diary);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PatientShellScope(
      tab: _tab,
      child: ValueListenableBuilder<int>(
        valueListenable: _tab,
        builder: (context, index, _) => PopScope(
          // Indietro da una scheda secondaria torna al diario
          canPop: index == PatientTab.diary,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _tab.value = PatientTab.diary;
          },
          child: IndexedStack(
            index: index,
            children: const [
              HomeScreen(),
              FavoritesScreen(),
              ProgressScreen(),
              ProfileScreen(),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class PatientTab {
  static const diary = 0;
  static const foods = 1;
  static const progress = 2;
  static const profile = 3;
}

/// Espone la scheda corrente alle schermate della shell: la barra la usa per
/// cambiare scheda, le schede per ricaricare i dati quando tornano visibili.
class PatientShellScope extends InheritedWidget {
  final ValueNotifier<int> tab;

  const PatientShellScope({super.key, required this.tab, required super.child});

  static ValueNotifier<int>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PatientShellScope>()?.tab;

  @override
  bool updateShouldNotify(PatientShellScope oldWidget) => tab != oldWidget.tab;
}

/// Ricarica i dati di una scheda ogni volta che torna visibile.
mixin ReloadOnTabVisible<T extends StatefulWidget> on State<T> {
  int get tabIndex;
  void onTabVisible();

  ValueNotifier<int>? _tab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tab = PatientShellScope.maybeOf(context);
    if (tab != _tab) {
      _tab?.removeListener(_onTabChanged);
      _tab = tab?..addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    if (_tab?.value == tabIndex && mounted) onTabVisible();
  }

  @override
  void dispose() {
    _tab?.removeListener(_onTabChanged);
    super.dispose();
  }
}
