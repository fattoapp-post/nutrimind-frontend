import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_error.dart';
import '../../core/food_service.dart';
import '../../core/models.dart';

/// Esito della scansione, restituito con `Navigator.pop`.
sealed class ScanOutcome {
  const ScanOutcome();
}

/// Prodotto trovato: era già nel catalogo oppure è stato appena
/// importato da Open Food Facts.
final class ScanFound extends ScanOutcome {
  final Food food;
  const ScanFound(this.food);
}

/// Il codice non esiste da nessuna parte e chi ha scansionato ha scelto
/// di inserire il prodotto a mano.
final class ScanCreate extends ScanOutcome {
  final String barcode;
  const ScanCreate(this.barcode);
}

/// Inquadra un codice a barre **e cerca il prodotto qui dentro**.
///
/// Prima questa schermata restituiva soltanto la stringa del codice e la
/// ricerca avveniva nel diario, dietro, annunciata da un messaggio a
/// comparsa. Tre conseguenze, tutte viste all'uso: l'attesa non si
/// capiva, perché il diario sembrava non fare niente; un codice assente
/// o un errore di rete riportavano al diario senza spiegazioni; e per
/// ritentare si doveva riaprire la fotocamera e inquadrare di nuovo.
///
/// Tenendo la ricerca qui l'attesa è visibile e bloccante, l'esito è
/// sempre dichiarato, e un tentativo a vuoto lascia la fotocamera dov'è,
/// pronta per il prossimo codice. Una sola inquadratura basta: le
/// rilevazioni che arrivano durante la ricerca vengono ignorate, quindi
/// non si accumulano ricerche sullo stesso prodotto.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

/// In quale momento si trova la schermata.
enum _Phase {
  /// Fotocamera attiva, in attesa di un codice.
  scanning,

  /// Ricerca in corso: nessuna nuova rilevazione viene accettata.
  searching,

  /// Ricerca finita male. La fotocamera è ancora accesa ma ferma in
  /// attesa che si scelga cosa fare.
  stopped,
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _camera = MobileScannerController(
    // `noDuplicates` scarterebbe per sempre un codice già visto: dopo un
    // errore di rete riquadrare lo stesso prodotto non farebbe più
    // niente. Il doppione lo evita `_phase`, che è una regola nostra e
    // si può riaprire con "Riprova".
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 500,
  );

  _Phase _phase = _Phase.scanning;
  String? _code;
  String? _message;
  bool _canCreate = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_phase != _Phase.scanning) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        _lookup(raw);
        return;
      }
    }
  }

  /// `FoodService.getFoodByBarcode` guarda prima il nostro catalogo e,
  /// se non lo trova, chiama la Edge Function che importa da Open Food
  /// Facts: le due ricerche sono già una sola chiamata, non serve
  /// chiederle separatamente.
  Future<void> _lookup(String barcode) async {
    setState(() {
      _phase = _Phase.searching;
      _code = barcode;
      _message = null;
      _canCreate = false;
    });

    try {
      // Un tetto al tempo di attesa: senza, una rete che non risponde
      // lascerebbe l'attesa aperta per sempre, ed è proprio la
      // situazione in cui serve dire qualcosa.
      final food = await FoodService.getFoodByBarcode(barcode)
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;

      if (food != null) {
        Navigator.pop(context, ScanFound(food));
        return;
      }
      setState(() {
        _phase = _Phase.stopped;
        _message = 'Il codice $barcode non è nel nostro catalogo e non '
            'risulta nemmeno su Open Food Facts.';
        _canCreate = true;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.stopped;
        _message = 'La ricerca non ha risposto in tempo. Controlla la '
            'connessione e riprova.';
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.stopped;
        _message = e.message;
      });
    }
  }

  void _retry() => setState(() {
        _phase = _Phase.scanning;
        _message = null;
        _code = null;
        _canCreate = false;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _camera, onDetect: _onDetect),
          SafeArea(child: _buildFrame()),
          if (_phase == _Phase.searching) _buildWaiting(),
          if (_phase == _Phase.stopped) _buildFailed(),
        ],
      ),
    );
  }

  /// Mirino e istruzioni. Il riquadro si adatta alla larghezza dello
  /// schermo invece di essere fisso a 300 px: su un telefono stretto
  /// quello fisso arrivava a toccare i bordi.
  Widget _buildFrame() {
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth * 0.78).clamp(220.0, 360.0);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _roundButton(Icons.close, () => Navigator.pop(context)),
                  const Expanded(
                    child: Text(
                      'Scansiona codice a barre',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _roundButton(Icons.flash_on, () => _camera.toggleTorch()),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: width,
              height: width * 0.5,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.qr_code_scanner, color: Colors.white54, size: 40),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _phase == _Phase.scanning
                    ? 'Inquadra il codice a barre del prodotto.\nLa ricerca parte da sola.'
                    : ' ',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
              ),
            ),
            const Spacer(flex: 2),
          ],
        );
      },
    );
  }

  /// L'attesa: copre tutto e non si può toccare niente sotto, perché
  /// finché non c'è un esito non c'è nulla da decidere.
  Widget _buildWaiting() {
    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('Cerco il prodotto…',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              _code ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Prima nel catalogo NutriMind, poi su Open Food Facts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Esito negativo. Si resta sulla fotocamera: "Riprova" la riapre
  /// subito, senza passare dal diario.
  Widget _buildFailed() {
    return Container(
      color: Colors.black.withValues(alpha: 0.86),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_canCreate ? Icons.search_off : Icons.wifi_off, color: Colors.white, size: 44),
                const SizedBox(height: 16),
                Text(
                  _canCreate ? 'Prodotto non trovato' : 'Ricerca non riuscita',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _message ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Riprova a inquadrare'),
                  ),
                ),
                if (_canCreate && _code != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, ScanCreate(_code!)),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                      label: const Text('Inseriscilo tu', style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Chiudi', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
