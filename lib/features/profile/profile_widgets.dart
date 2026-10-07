import 'package:flutter/material.dart';

import '../../core/app_error.dart';

/// Palette e componenti comuni alle pagine del profilo.
abstract final class ProfilePalette {
  static const bg = Color(0xFFFAFAFA);
  static const teal = Color(0xFF127B6D);
  static const tealSoft = Color(0xFFE6F4F1);
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
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
    return Scaffold(
      backgroundColor: ProfilePalette.bg,
      appBar: AppBar(
        backgroundColor: ProfilePalette.bg,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: ProfilePalette.textPrimary, fontWeight: FontWeight.bold)),
        bottom: busy
            ? const PreferredSize(
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(title!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ProfilePalette.textPrimary)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle!, style: const TextStyle(color: ProfilePalette.textSecondary)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(color: ProfilePalette.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 64, color: Colors.grey.shade200),
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
  final Color color;
  final int badge;

  const MenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color = ProfilePalette.teal,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(icon, color: color, size: 22)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: ProfilePalette.textPrimary)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: ProfilePalette.textSecondary)),
      trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right, color: ProfilePalette.textSecondary)),
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
