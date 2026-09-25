import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_motion.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';

/// One option of a single choice, as a row: the label, and a ring that fills
/// when it is the one chosen.
///
/// The whole row is the tap target. Replaces `RadioListTile`, whose padding,
/// type and ripple do not match the rows around it.
class AppChoiceRow<T> extends StatelessWidget with GroupedRow {
  const AppChoiceRow({
    super.key,
    required this.value,
    required this.groupValue,
    required this.label,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final T value;
  final T groupValue;
  final String label;
  final String? subtitle;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = value == groupValue;
    final active = enabled && onChanged != null;

    return Semantics(
      button: true,
      selected: selected,
      enabled: active,
      label: subtitle == null ? label : '$label. $subtitle',
      excludeSemantics: true,
      child: AppListRowShell(
        onTap: active ? () => onChanged!(value) : null,
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.short),
              curve: AppMotion.standard,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outline,
                  width: selected ? 7 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: active
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
