import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

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
  final theme = Theme.of(messenger.context);
  // The check is in the "done" green of the *other* theme: the bar is the
  // inverse surface, light on the dark theme and dark on the light one.
  final done = theme.brightness == Brightness.dark
      ? AppTones.light.success
      : AppTones.dark.success;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: done),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: Text(message)),
          ],
        ),
        action: onUndo == null
            ? null
            : SnackBarAction(label: 'Desfazer', onPressed: onUndo),
        // Flutter keeps a snack bar with an action on screen until it is
        // tapped. "Desfazer" stayed over every tab for as long as the app was
        // open after one tap on Feito. It goes after a while like any other
        // confirmation — except under a screen reader, where reaching the
        // button takes longer than any timeout.
        duration: onUndo == null
            ? const Duration(seconds: 4)
            : const Duration(seconds: 6),
        persist:
            onUndo != null &&
            MediaQuery.accessibleNavigationOf(messenger.context),
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
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 20,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
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
