import 'package:flutter/material.dart';

/// The one confirmation dialog.
///
/// Seven screens had written the same twenty lines: a question as the title,
/// a body saying what actually happens, Cancelar, and the verb. They agreed on
/// the shape by luck, and one of them would eventually not.
///
/// Two rules the shape encodes:
///
/// - **The confirm button says the verb**, never "Confirmar" or "OK". Someone
///   reading only the buttons still knows which one deletes.
/// - **[destructive] is the only thing that paints red.** It marks what cannot
///   be undone, so an action that merely changes a setting does not borrow the
///   colour that means "this is gone".
///
/// Returns false when dismissed, so a barrier tap is a "no".
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Signing out is not destructive — nothing is lost — but it is a surprise if
/// it happens on a mistaken tap, which is what earns it a confirmation.
Future<bool> confirmLogout(BuildContext context) {
  return confirmAction(
    context,
    title: 'Sair desta conta?',
    message: 'Você sai neste aparelho. Para voltar, use e-mail e senha.',
    confirmLabel: 'Sair',
  );
}
