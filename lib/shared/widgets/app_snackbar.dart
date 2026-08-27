import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Confirms a write that worked.
///
/// Carries a light tap because these fire while the phone is held at arm's
/// length next to a pump or a counter, where the screen is not always being
/// watched at the moment the request returns. It is the only haptic in the
/// app: one signal that means "saved", and nothing that buzzes on failure.
void showAppSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  VoidCallback? onUndo,
}) {
  // Nothing waits on it, and a device with no vibrator is not an error worth
  // surfacing to someone who just saved a service record.
  unawaited(HapticFeedback.lightImpact());
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

/// Reports a write that did not work, in the error colours.
///
/// Separate from [showAppSnackBar] because the two used to be one call:
/// "Veículo excluído." and the failure that stopped it arrived in the same
/// grey box, and the difference between them is the whole message. No haptic —
/// a buzz on a failure is a punishment, not information.
void showAppErrorSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
}) {
  final theme = Theme.of(messenger.context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        backgroundColor: theme.colorScheme.errorContainer,
        // Longer than a confirmation, and dismissible: a failure is something
        // to read, not something to catch.
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
        closeIconColor: theme.colorScheme.onErrorContainer,
      ),
    );
}
