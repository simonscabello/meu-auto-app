import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';

/// A settings line: what it is on the left, what it is set to on the right.
///
/// It shows the current value and opens somewhere to change it. A permanent
/// text field with a "Salvar" button beside it is a form, and a form is what
/// a settings screen stops being the moment it has more than one thing in it.
class AppSettingRow extends StatelessWidget with GroupedRow {
  const AppSettingRow({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.onTap,
    this.trailing,
    this.destructive = false,
  }) : toggled = null,
       onToggled = null;

  /// A yes/no setting that changes in place: a switch where the value and
  /// the chevron would be, and a tap anywhere on the line flips it. A screen
  /// reader hears a switch and its state, not a button.
  ///
  /// The same line as its neighbours — glyph, label, padding — so a switch
  /// in a group of rows that open somewhere does not start its text at a
  /// different place. `AppSwitchRow` is the form's version, with a subtitle
  /// and no glyph.
  const AppSettingRow.toggle({
    super.key,
    required this.label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.icon,
  }) : toggled = value,
       onToggled = onChanged,
       value = null,
       onTap = null,
       trailing = null,
       destructive = false;

  final String label;

  /// The current setting, shown on the right. Null for a row that is purely
  /// a way in — "Meus veículos" has no value to show.
  final String? value;

  final IconData? icon;
  final VoidCallback? onTap;

  /// Replaces the value and the chevron. For a row whose control lives in
  /// place that is not a plain switch — use [AppSettingRow.toggle] for that.
  final Widget? trailing;

  /// Paints the label in the error colour. For sign-out and account deletion,
  /// which must not look like the rows above them.
  final bool destructive;

  /// Set only by [AppSettingRow.toggle]: whether the switch is on.
  final bool? toggled;

  /// Null disables the switch — while a change is in flight, say.
  final ValueChanged<bool>? onToggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final labelColor = destructive ? scheme.error : scheme.onSurface;
    final isToggle = toggled != null;

    final row = Row(
      children: [
        if (icon != null) ...[
          AppIconWell(icon: icon!, color: destructive ? scheme.error : null),
          const SizedBox(width: AppSpacing.s12),
        ],
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(color: labelColor),
          ),
        ),
        if (isToggle)
          // The line is the tap target; the switch only shows the state.
          ExcludeSemantics(
            child: Switch(
              value: toggled!,
              onChanged: onToggled,
              // The line already gives the 48dp target; the switch's own
              // padding would make the row taller than its neighbours.
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        else if (trailing != null)
          trailing!
        else ...[
          // Capped, not flexible: a Flexible beside the Expanded label took
          // half the line and left the chevron in the middle of the row
          // whenever the value was short.
          if (value != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.45,
              ),
              child: Text(
                value!,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ],
        ],
      ],
    );

    final inset = AppGroupScope.paddingOf(context);
    final padded = Padding(
      padding: EdgeInsets.fromLTRB(
        inset.left,
        // The switch is taller than a line of text; less padding keeps the
        // row exactly as tall as the ones around it.
        isToggle ? AppSpacing.s4 : AppSpacing.s12,
        inset.right,
        isToggle ? AppSpacing.s4 : AppSpacing.s12,
      ),
      child: row,
    );

    final VoidCallback? tap = isToggle
        ? (onToggled == null ? null : () => onToggled!(!toggled!))
        : onTap;
    if (tap == null && !isToggle) {
      return padded;
    }

    return Semantics(
      container: true,
      button: !isToggle,
      toggled: toggled,
      enabled: isToggle ? onToggled != null : null,
      label: value == null ? label : '$label. $value',
      excludeSemantics: true,
      onTap: tap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tap,
          borderRadius: inset == EdgeInsets.zero
              ? AppRadius.borderS
              : BorderRadius.zero,
          highlightColor: tones.overlayPressed,
          splashColor: tones.overlayPressed,
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
