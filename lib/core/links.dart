import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Apre un link esterno (social, sito) nel browser o nell'app dedicata.
/// Accetta solo https: i link arrivano da contenuti degli utenti.
Future<void> openExternalLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  final messenger = ScaffoldMessenger.of(context);
  if (uri == null || uri.scheme != 'https') {
    messenger.showSnackBar(const SnackBar(content: Text('Link non valido.')));
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) messenger.showSnackBar(const SnackBar(content: Text('Impossibile aprire il link.')));
}

/// Normalizza un link inserito dall'utente: aggiunge https:// se manca.
/// Restituisce null se vuoto, lancia [FormatException] se non valido.
String? normalizeHttpsUrl(String? input) {
  final s = input?.trim() ?? '';
  if (s.isEmpty) return null;
  final withScheme = s.startsWith(RegExp(r'https?://', caseSensitive: false)) ? s : 'https://$s';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasAuthority || !uri.host.contains('.')) {
    throw const FormatException('Link non valido');
  }
  return uri.replace(scheme: 'https').toString();
}

/// Etichetta e icona per un link social, riconosciuto dal dominio.
({String label, IconData icon}) socialLinkStyle(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host.contains('instagram')) return (label: 'Instagram', icon: Icons.camera_alt_outlined);
  if (host.contains('tiktok')) return (label: 'TikTok', icon: Icons.music_note_outlined);
  if (host.contains('youtube') || host.contains('youtu.be')) return (label: 'YouTube', icon: Icons.play_circle_outline);
  if (host.contains('facebook')) return (label: 'Facebook', icon: Icons.facebook);
  return (label: 'Link', icon: Icons.link);
}
