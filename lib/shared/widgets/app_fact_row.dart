import 'package:flutter/material.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';

/// A label and its value, as one row of a facts group on a detail screen.
///
/// Two shapes. Stacked — the label small above the value — for a fact whose
/// value is a sentence ("Nunca foi feito — contamos a partir de quando o
/// carro era novo"). Inline — label left, value right — for a sheet of short
/// facts, where stacking would turn six lines into a screen and a half.
///
/// Tappable only when there is somewhere to go: the interval opens its
/// sheet, a phone number dials; "15 de julho" is not somewhere to go.
class AppFactRow extends StatelessWidget with GroupedRow {
  const AppFactRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.inline = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool inline;

  /// Overrides the value colour — the accent for a value that is a link.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // With the text enlarged an inline fact stacks like the others: a third
    // of a 360dp line broke "Preço por litro" over two lines beside "R$ 6,19".
    final inline = this.inline && !AppTypography.isLargeText(context);
    final labelStyle = inline
        ? theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)
        : theme.textTheme.labelMedium;
    final valueStyle =
        (inline ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: valueColor ?? (onTap == null ? null : scheme.primary),
            );

    final Widget body = inline
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: labelStyle)),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                flex: 2,
                child: Text(value, style: valueStyle, textAlign: TextAlign.end),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(height: 2),
              Text(value, style: valueStyle),
            ],
          );

    return AppListRowShell(
      onTap: onTap,
      semanticLabel: '$label. $value',
      child: Row(
        children: [
          Expanded(child: body),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ],
        ],
      ),
    );
  }
}
