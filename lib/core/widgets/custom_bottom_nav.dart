import 'package:flutter/material.dart';

import '../theme.dart';

import '../../features/shell/patient_shell.dart';

/// Barra di navigazione del paziente. Cambia scheda nella [PatientShell]
/// (nessun push di route), lasciando spazio al FAB centrale.
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    final selectedColor = palette.isDark ? palette.textPrimary : palette.teal;
    final unselectedColor = palette.textSecondary;
    final tab = PatientShellScope.maybeOf(context);

    Widget item(IconData icon, String label, int index) {
      final isSelected = currentIndex == index;
      final color = isSelected ? selectedColor : unselectedColor;
      return Expanded(
        child: InkWell(
          onTap: () {
            if (!isSelected) tab?.value = index;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return BottomAppBar(
      color: palette.bg,
      surfaceTintColor: Colors.transparent,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: Row(
        children: [
          item(Icons.book, 'Diario', PatientTab.diary),
          item(Icons.restaurant, 'Alimenti', PatientTab.foods),
          const SizedBox(width: 56),
          item(Icons.insights_outlined, 'Progressi', PatientTab.progress),
          item(Icons.person_outline, 'Profilo', PatientTab.profile),
        ],
      ),
    );
  }
}
