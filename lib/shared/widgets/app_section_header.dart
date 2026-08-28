import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';

/// The label above a group of rows.
///
/// Deliberately *quieter* than the content it introduces. It used to be
/// `titleMedium` — 16px semibold — which put it in a shouting match with the
/// item names underneath, and the result was a screen where everything was
/// bold and nothing was first. A section label organises; the content is what
/// the eye should land on.
///
/// Sentence case, not caps: pt-BR section names are long enough that
/// "PRECISAM DE ATENÇÃO" reads as an alarm rather than as a heading.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.count,
  });

  final String title;

  /// One quiet line explaining the group, when the name is not enough.
  final String? subtitle;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shown beside the label. Only worth it when the number is the reason the
  /// group exists — how many are late, not how many exist.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.4,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    count == null ? title : '$title · $count',
                    style: labelStyle,
                  ),
                ),
              ),
              if (actionLabel != null)
                AppButton(
                  label: actionLabel!,
                  variant: AppButtonVariant.tertiary,
                  onPressed: onAction,
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
