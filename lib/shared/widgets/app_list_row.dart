import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';

/// One scannable line: a glyph, a name, one line of state, and whatever the
/// row is worth on the right.
///
/// [accent] is the only colour a row carries, and it is deliberately small:
/// the group a row sits under already says whether it is urgent, and
/// [subtitle] says it in words. Colour is the third signal, never the only
/// one. Passing [status] tints the glyph and the state line together;
/// passing [accent] alone tints just the state line.
///
/// **[trailing] sits outside the row's tap target, always.** A row whose
/// right-hand side is a button has two actions in it, and a tap on the button
/// must never mean the row — including while that button is disabled, which
/// is exactly when a fall-through would fire during a write already in
/// flight.
class AppListRow extends StatelessWidget with GroupedRow {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accent,
    this.status,
    this.trailing,
    this.value,
    this.strongValue = false,
    this.titleMaxLines,
    this.onTap,
    this.showChevron = false,
    this.semanticLabel,
    this.iconTone,
  });

  final String title;

  /// The single line under the name. Join the parts with ` · ` — two lines of
  /// metadata is the card this widget exists to replace.
  final String? subtitle;

  final IconData? icon;

  /// Tints the state line. Reserved for rows that are actually late or
  /// close: tinting every row is the same as tinting none.
  final Color? accent;

  /// A loud status — late or close — that tints the glyph as well as the
  /// text. Quiet statuses are ignored, so a row can pass its status
  /// unconditionally.
  final AppStatus? status;

  /// An action of its own. Never part of [onTap].
  final Widget? trailing;

  /// A short figure on the right that belongs to the row — "R$ 389,90",
  /// "Rafael" — and is part of its tap target, unlike [trailing].
  final String? value;

  /// Sets [value] as a figure — an amount, a total — in the text colour and
  /// tabular, rather than as a quiet setting.
  final bool strongValue;

  /// Caps the name — a service record names every item it covered, and six
  /// of them made a row seven lines tall. Null lets the name wrap freely.
  final int? titleMaxLines;

  final VoidCallback? onTap;
  final bool showChevron;

  /// Overrides what a screen reader announces. Defaults to title + subtitle,
  /// which is what a sighted person reads.
  final String? semanticLabel;

  /// Forces the glyph's tone — accent for the "add" row at the foot of a
  /// group, say. Defaults to neutral, or status when [status] is loud.
  final AppIconWellTone? iconTone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final loud = status?.isLoud ?? false;
    final visual = loud ? statusColors(status!, theme.brightness) : null;
    final textAccent = accent ?? visual?.foreground;
    final isAdd = iconTone == AppIconWellTone.accent;
    final inset = AppGroupScope.paddingOf(context);

    final main = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          AppIconWell(
            icon: icon!,
            tone:
                iconTone ??
                (loud ? AppIconWellTone.status : AppIconWellTone.neutral),
            status: status,
          ),
          const SizedBox(width: AppSpacing.s12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: titleMaxLines,
                overflow: titleMaxLines == null ? null : TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  // An "add" row is an action, and reads in the accent like
                  // every other action that is text.
                  color: isAdd ? scheme.primary : null,
                  fontWeight: isAdd ? FontWeight.w600 : null,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textAccent ?? scheme.onSurfaceVariant,
                    fontWeight: textAccent == null ? null : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (value != null) ...[
          const SizedBox(width: AppSpacing.s12),
          Text(
            value!,
            style: strongValue
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabular,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
          ),
        ],
        if (showChevron) ...[
          const SizedBox(width: AppSpacing.s4),
          Icon(
            Icons.chevron_right,
            size: 20,
            // Fainter than the supporting text: the arrow is the least
            // important thing on the row.
            color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
        ],
      ],
    );

    Widget tappable = Padding(
      padding: EdgeInsets.fromLTRB(
        inset.left,
        AppSpacing.s12,
        trailing == null ? inset.right : 0,
        AppSpacing.s12,
      ),
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
            // Square inside a group, where the card's own corners clip the
            // ink; rounded on the page, where nothing else would.
            borderRadius: inset == EdgeInsets.zero
                ? AppRadius.borderS
                : BorderRadius.zero,
            highlightColor: tones.overlayPressed,
            splashColor: tones.overlayPressed,
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
        SizedBox(width: inset.right),
      ],
    );
  }

  String _spoken() {
    final detail = subtitle?.trim();
    final parts = [
      title,
      if (detail != null && detail.isNotEmpty) detail,
      ?value,
    ];
    return parts.join('. ');
  }
}

/// The tap target, padding and semantics of a row, around content of your
/// own.
///
/// [AppListRow] is the common shape — glyph, name, one line of state — and
/// most lists want exactly that. A few genuinely do not: a fill carries a
/// third line explaining a consumption the server could not compute, and a
/// service record carries a cost column. Those build their own interior and
/// take the rest from here, so every row in the app still has the same
/// height, the same rhythm and the same 48dp minimum whatever is inside it.
class AppListRowShell extends StatelessWidget with GroupedRow {
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
    final tones = AppTones.of(context);
    final inset = AppGroupScope.paddingOf(context);
    final padded = Padding(
      padding: EdgeInsets.fromLTRB(
        inset.left,
        AppSpacing.s12,
        inset.right,
        AppSpacing.s12,
      ),
      child: child,
    );

    if (onTap == null) {
      if (semanticLabel == null) return padded;
      return Semantics(
        label: semanticLabel,
        container: true,
        excludeSemantics: true,
        child: padded,
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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

/// The hairline between rows that sit on the page rather than inside an
/// [AppGroup] — the long, scrolling lists.
///
/// Indented to the text column so the rows read as one list rather than as
/// separate blocks.
class AppRowDivider extends StatelessWidget {
  const AppRowDivider({super.key, this.indent = 36});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      color: AppTones.of(context).divider,
    );
  }
}
