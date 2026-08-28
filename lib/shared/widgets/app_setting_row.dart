import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

/// A settings line: what it is on the left, what it is set to on the right.
///
/// The pattern the Perfil screen was missing. A permanent text field with a
/// "Salvar nome" button beside it is a form, and a form is what a settings
/// screen stops being the moment it has more than one thing in it. This shows
/// the current value and opens somewhere to change it.
class AppSettingRow extends StatelessWidget {
  const AppSettingRow({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final String label;

  /// The current setting, shown on the right. Null for a row that is purely
  /// a way in — "Meus veículos" has no value to show.
  final String? value;

  final IconData? icon;
  final VoidCallback? onTap;

  /// Replaces the value and the chevron. For a row whose control lives in
  /// place — a switch, say.
  final Widget? trailing;

  /// Paints the label in the error colour. For sign-out and account deletion,
  /// which must not look like the rows above them.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelColor = destructive ? scheme.error : scheme.onSurface;

    final row = Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 22,
            color: destructive ? scheme.error : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s16),
        ],
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(color: labelColor),
          ),
        ),
        if (trailing != null)
          trailing!
        else ...[
          if (value != null)
            Flexible(
              child: Text(
                value!,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s4),
            Icon(Icons.chevron_right, size: 20, color: scheme.outline),
          ],
        ],
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: row,
    );

    if (onTap == null) {
      return padded;
    }

    return Semantics(
      button: true,
      label: value == null ? label : '$label. $value',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderS,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTapTarget,
            ),
            child: padded,
          ),
        ),
      ),
    );
  }
}
