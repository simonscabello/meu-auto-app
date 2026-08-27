import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';

/// The conversation the server starts when a mileage does not fit its
/// neighbours.
///
/// This is deliberately not the generic error path. `odometer_rollback` is not
/// the app telling someone they typed badly — it is a question about their own
/// car, and the honest answer is sometimes "the value is right, the panel was
/// replaced". So it gets real figures and two ways out.
///
/// Shared rather than local to the sheet: a maintenance record carries a
/// mileage too and hits exactly the same rule, so Prompt 14 shows this same
/// dialog instead of writing a second one.
///
/// Set [allowOverride] to false where the endpoint has no way to force the
/// value through. `POST /odometer` accepts `source: "correction"`;
/// `PATCH /maintenance-records/{id}` accepts no such field, so offering the
/// button there would be a dead end dressed as a choice.
///
/// Returns true when the owner chose to record the value anyway. Dismissing
/// counts as going back to fix it.
Future<bool> showOdometerRollbackDialog(
  BuildContext context, {
  required OdometerRollback rollback,
  required String serverMessage,
  bool allowOverride = true,
}) async {
  final chose = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('Confira a quilometragem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rollback.explain(serverMessage)),
            if (allowOverride) ...[
              const SizedBox(height: AppSpacing.s12),
              Text(
                rollback.overrideHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Corrigir o valor'),
          ),
          if (allowOverride)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(OdometerRollback.overrideLabel),
            ),
        ],
      );
    },
  );
  return chose ?? false;
}
