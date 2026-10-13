import 'package:flutter/material.dart';

import '../theme.dart';

/// Immagine di un prodotto in un elenco.
///
/// Serve a rendere riconoscibile una riga: un nome come "Yogurt Greco 0%"
/// dice poco, la confezione si riconosce al volo.
///
/// Un'immagine che non arriva **non deve lasciare un buco**: senza
/// indirizzo, mentre carica o se il caricamento fallisce si disegna
/// sempre un riquadro della stessa misura con un'icona dentro, così
/// l'elenco non si muove sotto il dito.
///
/// Sul web il caricamento dipende dalle intestazioni CORS del sito che
/// ospita le immagini (per gli alimenti è Open Food Facts), e non è
/// detto che ci siano. Su Android e iOS il CORS non si applica. In tutti
/// i casi che vanno male si vede il segnaposto, mai un errore.
class FoodThumb extends StatelessWidget {
  final String? url;
  final double size;

  /// Icona del segnaposto: un piatto per gli alimenti, un libro di
  /// ricette dove si mostrano ricette.
  final IconData icon;

  const FoodThumb({
    super.key,
    this.url,
    this.size = 48,
    this.icon = Icons.restaurant_outlined,
  });

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    final radius = BorderRadius.circular(size * 0.25);
    final address = url?.trim();

    if (address == null || address.isEmpty) return _placeholder(radius);

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        address,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Le immagini del catalogo esterno hanno misure molto diverse
        // fra loro: senza questo, una foto grande verrebbe decodificata
        // a piena risoluzione per riempire 48 pixel.
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, _, _) => _placeholder(radius),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholder(radius),
      ),
    );
  }

  Widget _placeholder(BorderRadius radius) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tealSoft,
          borderRadius: radius,
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: size * 0.45, color: primaryTeal),
      );
}
