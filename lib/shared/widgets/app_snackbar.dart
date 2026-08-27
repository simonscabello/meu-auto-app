import 'package:flutter/material.dart';

void showAppSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  VoidCallback? onUndo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: onUndo == null
            ? null
            : SnackBarAction(label: 'Desfazer', onPressed: onUndo),
      ),
    );
}
