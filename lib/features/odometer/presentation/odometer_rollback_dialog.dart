import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';

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
/// value through. Every write that can answer this today — the odometer, a
/// maintenance record and a fill, created or edited — accepts
/// `source: "correction"`, and each caller must resend WITH it: resending the
/// same body without it only brings the same dialog back.
///
/// Returns true when the owner chose to record the value anyway. Dismissing
/// counts as going back to fix it.
///
/// The two answers are stacked, full width, rather than set side by side as
/// text: the override says what it does in six words, and squeezed into a
/// button bar it wrapped under its neighbour. Going back to fix the value is
/// the filled one — it is what most of these conversations end in, and the
/// safe answer should be the easy one.
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
        scrollable: true,
        // The page gutter rather than Material's wider inset: the override
        // spells out what it does, and on a common phone it then fits one
        // line.
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.s24,
        ),
        title: const Text('Confira a quilometragem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The figures are the point, so they read in the text colour;
            // the help under them is the quiet line.
            Text(
              rollback.explain(serverMessage),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (allowOverride) ...[
              const SizedBox(height: AppSpacing.s12),
              Text(rollback.overrideHelp, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.s24),
            AppButton(
              label: 'Corrigir o valor',
              expanded: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            if (allowOverride) ...[
              const SizedBox(height: AppSpacing.s4),
              AppButton(
                label: OdometerRollback.overrideLabel,
                variant: AppButtonVariant.tertiary,
                expanded: true,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ],
        ),
      );
    },
  );
  return chose ?? false;
}
