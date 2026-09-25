import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// A title, and the rows it names, inside one surface.
///
/// **Several rows, one card.** A list drawn as one card per item says "twelve
/// separate things" when there is one thing with twelve lines, and it stacks
/// twelve borders on the screen. Here the group is the object and the row is
/// its content: one edge around all of them, hairlines between them.
///
/// **The hairline starts where the text starts**, not at the card's edge.
/// Aligned with the names it organises the reading; run edge to edge it cuts
/// the card in pieces.
///
/// For a long list that scrolls and filters — the history — the rows go
/// straight on the page instead (see `AppRowDivider`); a card that is taller
/// than the screen is not grouping anything.
class AppGroup extends StatelessWidget {
  const AppGroup({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.count,
    this.footnote,
    this.dividerIndent = iconIndent,
    this.emphasis = AppSectionEmphasis.title,
  });

  /// The rows. Each is padded horizontally by the group; a row keeps its own
  /// vertical padding and its own 48dp minimum, so [AppListRow] drops in
  /// unchanged.
  final List<Widget> children;

  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? count;

  /// One quiet line under the surface. For the caveat that belongs to the
  /// group rather than to any row in it — what a total includes, why a list
  /// is empty.
  final String? footnote;

  /// Where the hairline between rows starts, measured from the group's inner
  /// edge. Defaults to the text column of a row with an icon; pass
  /// [textIndent] for a group whose rows carry none.
  final double dividerIndent;

  final AppSectionEmphasis emphasis;

  /// A row's icon slot (24) plus the gap after it (12): where a row's text
  /// starts. `AppListRow` lays itself out on the same two numbers.
  static const double iconIndent = 36;

  /// Rows with no icon: the hairline starts with the text.
  static const double textIndent = 0;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && footnote == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final tones = AppTones.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          AppSectionHeader(
            title: title!,
            subtitle: subtitle,
            actionLabel: actionLabel,
            onAction: onAction,
            count: count,
            emphasis: emphasis,
          ),
        if (children.isNotEmpty)
          AppSurface(
            variant: AppSurfaceVariant.grouped,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.inset),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        indent: dividerIndent,
                        color: tones.divider,
                      ),
                    ),
                  frameGroupRow(children[i]),
                ],
              ],
            ),
          ),
        if (footnote != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(footnote!, style: theme.textTheme.bodySmall),
          ),
        ],
      ],
    );
  }
}

/// A row that pads itself gets the padding handed down, so its ink reaches
/// the card's edges; anything else is padded from the outside.
Widget frameGroupRow(Widget child) {
  if (child is GroupedRow) {
    return AppGroupScope(horizontalPadding: AppSpacing.inset, child: child);
  }
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.inset),
    child: child,
  );
}

/// The fill a grouped surface sits on. Shared so a screen that has to build
/// its own grouped block by hand matches the lists around it exactly.
Color groupSurfaceColor(ColorScheme scheme) => scheme.surfaceContainerLow;

/// The vertical rhythm between two groups. One value, so the page does not
/// drift as screens are edited.
const double appGroupGap = AppSpacing.block;
