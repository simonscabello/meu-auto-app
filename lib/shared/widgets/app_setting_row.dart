import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';

/// A settings line: what it is on the left, what it is set to on the right.
///
/// It shows the current value and opens somewhere to change it. A permanent
/// text field with a "Salvar" button beside it is a form, and a form is what
/// a settings screen stops being the moment it has more than one thing in it.
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
    final tones = AppTones.of(context);
    final labelColor = destructive ? scheme.error : scheme.onSurface;

    final row = Row(
      children: [
        if (icon != null) ...[
          AppIconWell(
            icon: icon!,
            size: AppIconWellSize.s,
            color: destructive ? scheme.error : null,
          ),
          const SizedBox(width: AppSpacing.s12),
        ],
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
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
          highlightColor: tones.overlayPressed,
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
