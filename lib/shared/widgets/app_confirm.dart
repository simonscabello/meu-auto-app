import 'package:flutter/material.dart';

Future<bool> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sair desta conta?'),
      content: const Text(
        'Você sai neste aparelho. Para voltar, use e-mail e senha.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sair'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
