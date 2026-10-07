import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tavolozza dell'app. Prima ogni schermata dichiarava i propri colori e
/// le dichiarazioni non concordavano: metà app era scura e metà chiara.
/// Ora i colori stanno qui e basta.
class AppPalette {
  final Brightness brightness;

  /// Sfondo della schermata.
  final Color bg;

  /// Sfondo delle schede e dei campi sopra [bg].
  final Color card;

  /// Bordi e separatori.
  final Color border;

  /// Testo principale e secondario.
  final Color textPrimary;
  final Color textSecondary;

  /// Colore del marchio e la sua versione tenue, per gli sfondi.
  final Color teal;
  final Color tealSoft;

  /// Proteine, carboidrati, grassi: identici nei due temi, perché sono
  /// un codice che si impara una volta sola.
  final Color macroProtein;
  final Color macroCarbs;
  final Color macroFat;

  /// Sfondi tenui degli stessi tre.
  final Color macroProteinBg;
  final Color macroCarbsBg;
  final Color macroFatBg;

  /// Avvisi (verifica mancante, paziente da seguire). Lo sfondo crema
  /// fisso, sul tema scuro, lasciava testo bianco su bianco.
  final Color warningBg;
  final Color warningFg;

  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.teal,
    required this.tealSoft,
    this.macroProtein = const Color(0xFF5A44F2),
    this.macroCarbs = const Color(0xFFF0A500),
    this.macroFat = const Color(0xFFEB5A0C),
    required this.macroProteinBg,
    required this.macroCarbsBg,
    required this.macroFatBg,
    required this.warningBg,
    required this.warningFg,
  });

  bool get isDark => brightness == Brightness.dark;
}

/// Tema scuro: è quello con cui l'app è nata, il Diario lo usa da sempre.
const darkPalette = AppPalette(
  brightness: Brightness.dark,
  bg: Color(0xFF101817),
  card: Color(0xFF17221F),
  border: Color(0xFF1D2C29),
  textPrimary: Colors.white,
  textSecondary: Color(0xFFA1AFA9),
  teal: Color(0xFF17A28C),
  tealSoft: Color(0xFF14312C),
  macroProteinBg: Color(0xFF1E1B3A),
  macroCarbsBg: Color(0xFF332A14),
  macroFatBg: Color(0xFF331F14),
  warningBg: Color(0xFF332A14),
  warningFg: Color(0xFFF0A500),
);

const lightPalette = AppPalette(
  brightness: Brightness.light,
  bg: Color(0xFFFAFAFA),
  card: Colors.white,
  border: Color(0xFFE5E7EB),
  textPrimary: Color(0xFF1F2937),
  textSecondary: Color(0xFF6B7280),
  teal: Color(0xFF127B6D),
  tealSoft: Color(0xFFE6F4F1),
  macroProteinBg: Color(0xFFF0EFFF),
  macroCarbsBg: Color(0xFFFEF6E5),
  macroFatBg: Color(0xFFFDEEE6),
  warningBg: Color(0xFFFFF7E6),
  warningFg: Color(0xFFB26A00),
);

/// Tema scelto dall'utente col pulsante sole/luna nel profilo.
///
/// La tavolozza si legge dalla variabile globale [palette], non da un
/// `InheritedWidget`. È una scelta pragmatica: al cambio di tema il
/// `MaterialApp` ricostruisce tutto l'albero, quindi ogni `build` rilegge
/// il valore aggiornato, e in cambio le schermate restano leggibili
/// (`bgColor` invece di `AppTheme.of(context).bg` in cento punti).
/// La regola è una sola: leggere i colori **dentro** `build`, mai
/// salvarli in un campo dello State.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark);

  static const _key = 'theme_mode';

  /// Legge la scelta salvata. Se non c'è, resta il tema scuro.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_key) == 'light') _apply(ThemeMode.light);
    } catch (_) {
      // preferenze non disponibili: si tiene il valore predefinito
    }
  }

  Future<void> toggle() => set(value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> set(ThemeMode mode) async {
    if (mode == value) return;
    _apply(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {
      // la scelta vale almeno per questa sessione
    }
  }

  /// L'ordine conta: assegnare `value` avvisa subito chi ascolta e fa
  /// ricostruire l'albero, quindi la tavolozza va aggiornata **prima**,
  /// altrimenti le schermate si ridisegnano con i colori vecchi.
  void _apply(ThemeMode mode) {
    palette = mode == ThemeMode.light ? lightPalette : darkPalette;
    value = mode;
  }
}

/// Unico controller dell'app.
final themeController = ThemeController();

/// Tavolozza in uso. La aggiorna [ThemeController].
AppPalette palette = darkPalette;

// Scorciatoie con i nomi che le schermate usavano già.
Color get bgColor => palette.bg;
Color get cardColor => palette.card;
Color get borderColor => palette.border;
Color get textPrimary => palette.textPrimary;
Color get textSecondary => palette.textSecondary;
Color get primaryTeal => palette.teal;
Color get tealSoft => palette.tealSoft;
Color get colorP => palette.macroProtein;
Color get colorC => palette.macroCarbs;
Color get colorG => palette.macroFat;
Color get bgP => palette.macroProteinBg;
Color get bgC => palette.macroCarbsBg;
Color get bgG => palette.macroFatBg;
Color get warningBg => palette.warningBg;
Color get warningFg => palette.warningFg;

/// Tema Material coerente con la tavolozza, così finestre di dialogo,
/// avvisi, fogli e campi di testo non stonano con le schermate.
ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? darkPalette : lightPalette;
  final base = ThemeData(brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.teal,
      brightness: brightness,
      primary: p.teal,
      surface: p.bg,
    ),
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.border,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: p.textPrimary),
      titleTextStyle: TextStyle(color: p.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(color: p.card, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(color: p.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      contentTextStyle: TextStyle(color: p.textSecondary, fontSize: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.isDark ? p.card : const Color(0xFF1F2937),
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: ListTileThemeData(
      textColor: p.textPrimary,
      iconColor: p.textSecondary,
      subtitleTextStyle: TextStyle(color: p.textSecondary, fontSize: 13),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      hintStyle: TextStyle(color: p.textSecondary),
      labelStyle: TextStyle(color: p.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.teal, width: 1.5),
      ),
    ),
    textTheme: (brightness == Brightness.dark ? base.textTheme : base.textTheme)
        .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary),
    iconTheme: IconThemeData(color: p.textSecondary),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.teal),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: p.teal, foregroundColor: Colors.white),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.teal)),
    chipTheme: ChipThemeData(
      backgroundColor: p.card,
      selectedColor: p.teal,
      side: BorderSide(color: p.border),
      labelStyle: TextStyle(color: p.textPrimary),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.teal : null,
      ),
    ),
  );
}

/// Registra la dipendenza dal tema corrente.
///
/// Serve perché le schermate leggono i colori dalla variabile globale
/// [palette], e Flutter salta la ricostruzione di un widget quando il
/// genitore gli passa la stessa istanza `const`: senza una dipendenza
/// esplicita, al cambio di tema la schermata resterebbe dei colori
/// vecchi. Con questa riga Flutter la segna da ricostruire direttamente,
/// qualunque cosa ci sia sopra di essa.
///
/// Va chiamata come prima istruzione di ogni `build` che usa i colori.
extension ThemeDependency on BuildContext {
  void watchTheme() => Theme.of(this);
}
