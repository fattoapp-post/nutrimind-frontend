import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/app_error.dart';

/// Nomi usati dalle pagine del profilo. I colori arrivano dalla
/// tavolozza scelta dall'utente (core/theme.dart): da leggere dentro
/// `build`, mai salvare in un campo.
abstract final class ProfilePalette {
  static Color get bg => palette.bg;
  static Color get card => palette.card;
  static Color get border => palette.border;
  static Color get teal => palette.teal;
  static Color get tealSoft => palette.tealSoft;
  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;
}

/// Pagina di impostazioni: AppBar chiara e contenuto scrollabile.
class SettingsPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool busy;
  final Widget? bottom;

  const SettingsPage({super.key, required this.title, required this.children, this.busy = false, this.bottom});

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return Scaffold(
      backgroundColor: ProfilePalette.bg,
      appBar: AppBar(
        backgroundColor: ProfilePalette.bg,
        elevation: 0,
        title: Text(title, style: TextStyle(color: ProfilePalette.textPrimary, fontWeight: FontWeight.bold)),
        bottom: busy
            ? PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3, color: ProfilePalette.teal),
              )
            : null,
      ),
      bottomNavigationBar: bottom == null ? null : SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: bottom)),
      body: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }
}

/// Riquadro bianco con titolo opzionale.
class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsets padding;

  const SectionCard({super.key, this.title, this.subtitle, required this.children, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: ProfilePalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProfilePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(title!, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ProfilePalette.textPrimary)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle!, style: TextStyle(color: ProfilePalette.textSecondary)),
            ),
          if (title != null || subtitle != null) const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Gruppo di voci di menu del profilo.
class MenuGroup extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const MenuGroup({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(color: ProfilePalette.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: ProfilePalette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ProfilePalette.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 64, color: ProfilePalette.border),
                items[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;
  final int badge;

  const MenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    final c = color ?? ProfilePalette.teal;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(icon, color: c, size: 22)),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: ProfilePalette.textPrimary)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(color: ProfilePalette.textSecondary)),
      trailing: trailing ?? (onTap == null ? null : Icon(Icons.chevron_right, color: ProfilePalette.textSecondary)),
    );
  }
}

/// Esegue un'azione con snackbar di esito; restituisce true se è riuscita.
Future<bool> runWithFeedback(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } on AppError catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Selettore a chip multipli su un insieme chiave -> etichetta.
class TagSelector extends StatelessWidget {
  final Map<String, String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>>? onChanged;

  const TagSelector({super.key, required this.options, required this.selected, this.onChanged});

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in options.entries)
          FilterChip(
            label: Text(e.value),
            selected: selected.contains(e.key),
            selectedColor: ProfilePalette.tealSoft,
            checkmarkColor: ProfilePalette.teal,
            onSelected: onChanged == null
                ? null
                : (on) => onChanged!(on ? {...selected, e.key} : ({...selected}..remove(e.key))),
          ),
      ],
    );
  }
}

/// Sole o luna: un tocco cambia il tema di tutta l'app e la scelta resta
/// salvata sul dispositivo. L'icona mostra **dove si va**, non dove si è:
/// con il tema scuro attivo si vede il sole, perché è quello che si
/// ottiene premendo.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.color});

  /// Colore dell'icona; per impostazione predefinita quello del testo.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    final toLight = palette.isDark;
    return IconButton(
      tooltip: toLight ? 'Passa al tema chiaro' : 'Passa al tema scuro',
      onPressed: themeController.toggle,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          toLight ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey(toLight),
          color: color ?? ProfilePalette.textPrimary,
        ),
      ),
    );
  }
}

/// Riga "Aspetto" con i due pulsanti affiancati, per chi preferisce
/// scegliere invece di alternare.
class ThemeChoiceTile extends StatelessWidget {
  const ThemeChoiceTile({super.key});

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    Widget option(String label, IconData icon, ThemeMode mode) {
      final selected = themeController.value == mode;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => themeController.set(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? ProfilePalette.tealSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? ProfilePalette.teal : ProfilePalette.border),
            ),
            child: Column(children: [
              Icon(icon, color: selected ? ProfilePalette.teal : ProfilePalette.textSecondary),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    color: selected ? ProfilePalette.teal : ProfilePalette.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  )),
            ]),
          ),
        ),
      );
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, child) => SectionCard(
        title: 'Aspetto',
        subtitle: 'Vale su questo dispositivo',
        children: [
          Row(children: [
            option('Chiaro', Icons.light_mode_outlined, ThemeMode.light),
            const SizedBox(width: 10),
            option('Scuro', Icons.dark_mode_outlined, ThemeMode.dark),
          ]),
        ],
      ),
    );
  }
}
