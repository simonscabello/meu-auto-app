import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

/// One scannable line: icon, name, one line of state, and whatever the row
/// is worth on the right.
///
/// This is the shape that replaced a card per item. A list of eighteen
/// maintenance plans as eighteen bordered boxes is a list nobody reads; the
/// same eighteen as rows under a section label can be scanned in a second.
/// The detail that used to be printed on every card now lives one tap away,
/// on the item itself.
///
/// [accent] is the only colour a row carries, and it is deliberately small:
/// the section a row sits under already says whether it is urgent, and
/// [subtitle] says it in words. Colour is the third signal, never the only
/// one.
///
/// **[trailing] sits outside the row's tap target, always.** A row whose
/// right-hand side is a button has two actions in it, and a tap on the button
/// must never mean the row — including while that button is disabled, which
/// is exactly when a fall-through would fire during a write already in
/// flight.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accent,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.semanticLabel,
  });

  final String title;

  /// The single line under the name. Join the parts with ` · ` — two lines of
  /// metadata is the card this widget exists to replace.
  final String? subtitle;

  final IconData? icon;

  /// Tints the icon and the state line. Reserved for rows that are actually
  /// late or close: tinting every row is the same as tinting none.
  final Color? accent;

  /// An action of its own, or a figure. Never part of [onTap].
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool showChevron;

  /// Overrides what a screen reader announces. Defaults to title + subtitle,
  /// which is what a sighted person reads.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconColor = accent ?? scheme.onSurfaceVariant;

    final main = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            // Optical alignment with the cap height of the title rather than
            // its line box, so the icon does not float above short names.
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.s12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyLarge),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accent ?? scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: AppSpacing.s4),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.chevron_right, size: 20, color: scheme.outline),
          ),
        ],
      ],
    );

    Widget tappable = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: main,
    );

    if (onTap != null) {
      tappable = Semantics(
        button: true,
        label: semanticLabel ?? _spoken(),
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
              child: tappable,
            ),
          ),
        ),
      );
    } else if (semanticLabel != null) {
      tappable = Semantics(
        label: semanticLabel,
        container: true,
        excludeSemantics: true,
        child: tappable,
      );
    }

    if (trailing == null) {
      return tappable;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: tappable),
        const SizedBox(width: AppSpacing.s12),
        trailing!,
      ],
    );
  }

  String _spoken() {
    final detail = subtitle?.trim();
    if (detail == null || detail.isEmpty) return title;
    return '$title. $detail';
  }
}

/// The tap target, padding and semantics of a row, around content of your
/// own.
///
/// [AppListRow] is the common shape — icon, name, one line of state — and
/// most lists want exactly that. A few genuinely do not: a fill carries a
/// third line explaining a consumption the server could not compute, and a
/// service record carries a cost column and an "Informado" marker. Those
/// build their own interior and take the rest from here, so that every row in
/// the app still has the same height, the same rhythm and the same 48dp
/// minimum whatever is inside it.
class AppListRowShell extends StatelessWidget {
  const AppListRowShell({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: child,
    );

    if (onTap == null) {
      return padded;
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
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

/// The hairline between rows in a group.
///
/// Indented past the icon column so the rows read as one list rather than as
/// separate blocks — the whole reason this is not a stack of cards.
class AppRowDivider extends StatelessWidget {
  const AppRowDivider({super.key, this.indent = 34});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(
        alpha: 0.55,
      ),
    );
  }
}
