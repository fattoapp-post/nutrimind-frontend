import 'package:flutter/material.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/community_models.dart';
import '../../core/links.dart';
import '../../core/models.dart';
import '../directory/nutritionist_public_screen.dart';
import 'profile_widgets.dart';

/// Nutrizionista: profilo pubblico mostrato nella vetrina "Trova un
/// nutrizionista" (professione, presentazione, specializzazioni, social).
class PublicProfileEditorScreen extends StatefulWidget {
  final Profile profile;

  const PublicProfileEditorScreen({super.key, required this.profile});

  @override
  State<PublicProfileEditorScreen> createState() => _PublicProfileEditorScreenState();
}

class _PublicProfileEditorScreenState extends State<PublicProfileEditorScreen> {
  final _headline = TextEditingController();
  final _studio = TextEditingController();
  final _bio = TextEditingController();
  final _city = TextEditingController();
  final _instagram = TextEditingController();
  final _tiktok = TextEditingController();
  final _youtube = TextEditingController();
  final _website = TextEditingController();

  String _profession = 'nutritionist';
  Set<String> _specialties = {};
  bool _online = true;
  bool _accepting = true;
  bool _isPublic = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<TextEditingController> get _all => [_headline, _studio, _bio, _city, _instagram, _tiktok, _youtube, _website];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await AccountService.getNutritionistDetails();
      if (!mounted) return;
      setState(() {
        _profession = d?.profession ?? 'nutritionist';
        _headline.text = d?.headline ?? '';
        _studio.text = d?.studioName ?? '';
        _bio.text = d?.bio ?? '';
        _city.text = d?.city ?? '';
        _instagram.text = d?.instagramUrl ?? '';
        _tiktok.text = d?.tiktokUrl ?? '';
        _youtube.text = d?.youtubeUrl ?? '';
        _website.text = d?.websiteUrl ?? '';
        _specialties = {...?d?.specialties};
        _online = d?.onlineConsultations ?? true;
        _accepting = d?.acceptingPatients ?? true;
        _isPublic = d?.isPublic ?? false;
      });
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  /// Costruisce i dettagli dal form; null (con messaggio) se un link non è valido.
  NutritionistDetails? _collect() {
    try {
      return NutritionistDetails(
        profession: _profession,
        headline: _opt(_headline),
        studioName: _opt(_studio),
        bio: _opt(_bio),
        city: _opt(_city),
        specialties: _specialties.toList(),
        onlineConsultations: _online,
        acceptingPatients: _accepting,
        isPublic: _isPublic,
        instagramUrl: normalizeHttpsUrl(_instagram.text),
        tiktokUrl: normalizeHttpsUrl(_tiktok.text),
        youtubeUrl: normalizeHttpsUrl(_youtube.text),
        websiteUrl: normalizeHttpsUrl(_website.text),
      );
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Controlla i link: uno non è valido.')));
      return null;
    }
  }

  Future<void> _save() async {
    final details = _collect();
    if (details == null) return;
    setState(() => _busy = true);
    final ok = await runWithFeedback(context, () => AccountService.updateNutritionistDetails(details), success: 'Profilo salvato.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  void _preview() {
    final d = _collect();
    if (d == null) return;
    final card = NutritionistCard(
      id: widget.profile.id,
      displayName: widget.profile.displayName,
      profession: d.profession,
      headline: d.headline,
      studioName: d.studioName,
      bio: d.bio,
      specialties: d.specialties,
      city: d.city,
      online: d.onlineConsultations,
      acceptingPatients: d.acceptingPatients,
      socials: SocialLinks(instagram: d.instagramUrl, tiktok: d.tiktokUrl, youtube: d.youtubeUrl, website: d.websiteUrl),
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => NutritionistPublicScreen(card: card)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return SettingsPage(title: 'Profilo pubblico', busy: _loading, children: [
        if (_error != null) Text(_error!),
      ]);
    }
    final verified = widget.profile.professionalVerified;
    return SettingsPage(
      title: 'Profilo pubblico',
      busy: _busy,
      bottom: Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _preview, icon: const Icon(Icons.visibility_outlined), label: const Text('Anteprima'))),
        const SizedBox(width: 12),
        Expanded(child: FilledButton(onPressed: _busy ? null : _save, child: const Text('Salva'))),
      ]),
      children: [
        SectionCard(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrami in "Trova un nutrizionista"'),
              subtitle: Text(verified
                  ? 'I pazienti potranno vedere la tua pagina, le ricette pubbliche e i piani, e scriverti.'
                  : 'Comparirai dopo la verifica professionale.'),
              value: _isPublic,
              activeThumbColor: ProfilePalette.teal,
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accetto nuovi pazienti'),
              value: _accepting,
              activeThumbColor: ProfilePalette.teal,
              onChanged: (v) => setState(() => _accepting = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Consulenze online'),
              value: _online,
              activeThumbColor: ProfilePalette.teal,
              onChanged: (v) => setState(() => _online = v),
            ),
          ],
        ),
        SectionCard(
          title: 'Presentazione',
          children: [
            DropdownButtonFormField<String>(
              initialValue: _profession,
              decoration: const InputDecoration(labelText: 'Professione'),
              items: [
                for (final e in professionLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _profession = v ?? 'nutritionist'),
            ),
            TextField(
              controller: _headline,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Frase di presentazione', hintText: 'Es. Alimentazione sportiva per runner'),
            ),
            TextField(controller: _studio, decoration: const InputDecoration(labelText: 'Studio')),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'Città')),
            TextField(controller: _bio, maxLines: 5, maxLength: 2000, decoration: const InputDecoration(labelText: 'Chi sei e come lavori')),
          ],
        ),
        SectionCard(
          title: 'Specializzazioni',
          children: [
            TagSelector(options: specialtyLabels, selected: _specialties, onChanged: (v) => setState(() => _specialties = v)),
          ],
        ),
        SectionCard(
          title: 'Social e sito',
          subtitle: 'Compaiono nella tua pagina pubblica.',
          children: [
            TextField(controller: _instagram, decoration: const InputDecoration(labelText: 'Instagram', hintText: 'instagram.com/tuoprofilo', prefixIcon: Icon(Icons.camera_alt_outlined))),
            TextField(controller: _tiktok, decoration: const InputDecoration(labelText: 'TikTok', hintText: 'tiktok.com/@tuoprofilo', prefixIcon: Icon(Icons.music_note_outlined))),
            TextField(controller: _youtube, decoration: const InputDecoration(labelText: 'YouTube', prefixIcon: Icon(Icons.play_circle_outline))),
            TextField(controller: _website, decoration: const InputDecoration(labelText: 'Sito web', prefixIcon: Icon(Icons.language))),
          ],
        ),
      ],
    );
  }
}
