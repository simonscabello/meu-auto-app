import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';

/// One scannable line: an icon in its well, a name, one line of state, and
/// whatever the row is worth on the right.
///
/// [accent] is the only colour a row carries, and it is deliberately small:
/// the group a row sits under already says whether it is urgent, and
/// [subtitle] says it in words. Colour is the third signal, never the only
/// one. Passing [status] tints the well and the state line together; passing
/// [accent] alone tints just the text and glyph.
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
    this.status,
    this.trailing,
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

  /// Tints the icon and the state line. Reserved for rows that are actually
  /// late or close: tinting every row is the same as tinting none.
  final Color? accent;

  /// A loud status — late or close — that tints the well as well as the text.
  /// Quiet statuses are ignored, so a row can pass its status unconditionally.
  final AppStatus? status;

  /// An action of its own, or a figure. Never part of [onTap].
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool showChevron;

  /// Overrides what a screen reader announces. Defaults to title + subtitle,
  /// which is what a sighted person reads.
  final String? semanticLabel;

  /// Forces the well's tone — accent for the "add" row at the foot of a
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
            color: iconTone == null && !loud ? accent : null,
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
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textAccent ?? scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: AppSpacing.s8),
          Icon(Icons.chevron_right, size: 20, color: scheme.outline),
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
            highlightColor: tones.overlayPressed,
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
    final tones = AppTones.of(context);
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

/// The hairline between rows that are not inside an [AppGroup].
///
/// Indented past the icon column so the rows read as one list rather than as
/// separate blocks.
class AppRowDivider extends StatelessWidget {
  const AppRowDivider({super.key, this.indent = 50});

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
