import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';

/// A yes/no setting inside a form: the question on the left, the switch on
/// the right, the whole row a tap target.
///
/// Material's `SwitchListTile` brings its own padding and type; this one
/// sits on the same rhythm as every other row in the app.
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: AppListRowShell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
