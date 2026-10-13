import 'package:flutter/material.dart';

import 'app_error.dart';
import 'theme.dart';

/// Come l'app comunica all'utente che qualcosa è andato bene o male.
///
/// Gli errori si mostrano con una **finestra da chiudere a mano**, non con
/// uno snackbar. Lo snackbar scompare da solo dopo qualche secondo: chi
/// stava guardando la tastiera, o chi ha cambiato schermata subito dopo,
/// non lo vede mai. In un'app che registra quello che una persona mangia,
/// un salvataggio fallito in silenzio è peggio di un fastidio — si crede
/// di avere un diario completo e non è vero.
///
/// I messaggi di conferma restano snackbar: un'operazione riuscita non ha
/// bisogno di fermare chi la stava facendo.

/// Finestra di errore. Il messaggio è selezionabile, così si può copiare
/// quando serve riferirlo a qualcuno.
Future<void> showErrorDialog(
  BuildContext context,
  String message, {
  String? title,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      ctx.watchTheme();
      return AlertDialog(
        backgroundColor: cardColor,
        icon: Icon(Icons.error_outline, color: colorG, size: 32),
        title: Text(
          title ?? 'Non ha funzionato',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: SelectableText(
          message,
          style: TextStyle(color: textSecondary, fontSize: 15, height: 1.35),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Chiudi'),
            ),
          ),
        ],
      );
    },
  );
}

/// Come [showErrorDialog] ma partendo dall'errore grezzo: lo normalizza
/// con [AppError], così all'utente non arriva mai un messaggio SQL.
Future<void> showAppError(BuildContext context, Object error, {String? title}) {
  return showErrorDialog(context, AppError.from(error).message, title: title);
}

/// Conferma breve: resta uno snackbar.
void showOk(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Esegue [action] mostrando un errore in finestra se fallisce e un
/// messaggio di conferma se riesce. Restituisce `true` solo se è andata.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
  String? errorTitle,
}) async {
  try {
    await action();
    if (!context.mounted) return true;
    if (success != null) showOk(context, success);
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    await showAppError(context, e, title: errorTitle);
    return false;
  }
}
