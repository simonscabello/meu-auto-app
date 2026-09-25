import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_row_body.dart';

export 'package:meu_auto/shared/widgets/app_row_body.dart';

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
    this.footnote,
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

  /// A short figure on the title's line that belongs to the row —
  /// "R$ 389,90", "12,4 km/L" — and is part of its tap target, unlike
  /// [trailing]. A figure, never a phrase: "Sem consumo ainda" as a value
  /// squeezed "Consumo" into a column that broke it mid-word. A phrase is
  /// the [subtitle]. See [AppRowBody] for where it goes when it is wide.
  final String? value;

  /// Sets [value] as a figure — an amount, a total — in the text colour and
  /// tabular, rather than as a quiet setting.
  final bool strongValue;

  /// Caps the name — a service record names every item it covered, and six
  /// of them made a row seven lines tall. Null lets the name wrap freely.
  final int? titleMaxLines;

  /// A second supporting line under [subtitle], for the rare row that has
  /// one more fact of its own — a part's warranty.
  final String? footnote;

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
          child: AppRowBody(
            title: title,
            titleMaxLines: titleMaxLines,
            titleStyle: isAdd
                // An "add" row is an action, and reads in the accent like
                // every other action that is text.
                ? TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)
                : null,
            subtitle: subtitle,
            subtitleStyle: textAccent == null
                ? null
                : TextStyle(color: textAccent, fontWeight: FontWeight.w500),
            footnote: footnote,
            value: value,
            strongValue: strongValue,
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: AppSpacing.s4),
          const AppRowChevron(),
        ],
      ],
    );

    // On the page, with nothing beside it, the ink reaches past the text
    // (see [_PageBleed]).
    final bleed = inset == EdgeInsets.zero && onTap != null && trailing == null;
    Widget tappable = Padding(
      padding: EdgeInsets.fromLTRB(
        inset.left + (bleed ? _PageBleed.bleed : 0),
        AppSpacing.s12,
        (trailing == null ? inset.right : 0) + (bleed ? _PageBleed.bleed : 0),
        AppSpacing.s12,
      ),
      child: main,
    );

    if (onTap != null) {
      tappable = Semantics(
        container: true,
        button: true,
        label: semanticLabel ?? _spoken(),
        excludeSemantics: true,
        onTap: onTap,
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
      if (bleed) tappable = _PageBleed(child: tappable);
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

    if (AppTypography.isLargeText(context)) {
      // Beside the words, a "Feito" left the name a column wide enough for
      // "arrefeciment / o". Under them, on the text's own edge, it keeps
      // its size and the name keeps the line.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tappable,
          Padding(
            padding: EdgeInsets.fromLTRB(
              inset.left + (icon == null ? 0 : AppSpacing.rowTextIndent),
              0,
              inset.right,
              AppSpacing.s12,
            ),
            child: trailing,
          ),
        ],
      );
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
      ?footnote,
      ?value,
    ];
    return parts.join('. ');
  }
}

/// The tap target, padding and semantics of a row, around content of your
/// own.
///
/// [AppListRow] is the common shape — glyph, name, one line of state — and
/// most lists want exactly that. A few genuinely do not: a reading with a
/// delete button beside it, a cost with a bar under it, a vehicle with a
/// tick. Those build their own interior and take the rest from here, so
/// every row in the app still has the same height, the same rhythm and the
/// same 48dp minimum whatever is inside it. A name with a figure beside it
/// is [AppRowBody], so it breaks its lines the way every other row does.
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

    final onPage = inset == EdgeInsets.zero;
    final Widget row = Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: onPage ? AppRadius.borderS : BorderRadius.zero,
          highlightColor: tones.overlayPressed,
          splashColor: tones.overlayPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTapTarget,
            ),
            child: onPage
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _PageBleed.bleed,
                    ),
                    child: padded,
                  )
                : padded,
          ),
        ),
      ),
    );
    return onPage ? _PageBleed(child: row) : row;
  }
}

/// Lets the pressed state of a row that sits straight on the page reach a
/// little past its text on both sides.
///
/// Inside a group the card's edge frames the ink. On the page nothing does,
/// and a highlight that started exactly where "Sem comprovante" starts read
/// as a box drawn around the words. The row is laid out [bleed] wider than
/// its slot and pulled back by the same amount, so the text stays on the
/// gutter and only the ink spills into the page margin.
class _PageBleed extends SingleChildRenderObjectWidget {
  const _PageBleed({required Widget super.child});

  static const double bleed = AppSpacing.s12;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPageBleed();
}

class _RenderPageBleed extends RenderShiftedBox {
  _RenderPageBleed() : super(null);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final parentData = child.parentData! as BoxParentData;
    if (!constraints.hasBoundedWidth) {
      child.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child.size);
      parentData.offset = Offset.zero;
      return;
    }
    final width = constraints.maxWidth + _PageBleed.bleed * 2;
    child.layout(
      constraints.copyWith(minWidth: width, maxWidth: width),
      parentUsesSize: true,
    );
    size = constraints.constrain(Size(constraints.maxWidth, child.size.height));
    parentData.offset = const Offset(-_PageBleed.bleed, 0);
  }
}

/// The hairline between rows that sit on the page rather than inside an
/// [AppGroup] — the long, scrolling lists.
///
/// Indented to the text column so the rows read as one list rather than as
/// separate blocks.
class AppRowDivider extends StatelessWidget {
  const AppRowDivider({super.key, this.indent = AppSpacing.rowTextIndent});

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
