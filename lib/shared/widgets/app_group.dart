import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';

/// A label, and the rows it names, inside one surface.
///
/// The app spent a while with no container at all: rows sat directly on the
/// page under a quiet label, separated by spacing alone. That fixed the
/// opposite problem — a bordered card around every single fact — but it went
/// one step too far. With nothing holding a group together, an alert, a
/// document and a total all float at the same level, and the eye has no way
/// to tell where one list ends and the next begins.
///
/// This is the middle: **the label stays outside and quiet, the rows go
/// inside one filled, rounded surface.** It is the grouped list every phone
/// already uses for settings, and it says three things a bare stack cannot:
///
///  * these rows are one thing;
///  * this thing ends here;
///  * the label above is a name, not a row.
///
/// The fill is one step off the page, never a border. [AppSurface] is still
/// the primitive for a *block* that is not a list — a hero reading, a
/// tinted status band. This is for the list.
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
    this.dividerIndent = 34,
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
  /// edge. Defaults to the icon column, so rows read as one list. Pass `0`
  /// for a group whose rows carry no icon.
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && footnote == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
          ),
        if (children.isNotEmpty)
          Container(
            // Clipped, not just decorated: a row's ink ripple would otherwise
            // paint square over the rounded corners it is sitting on.
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: groupSurfaceColor(scheme),
              borderRadius: AppRadius.borderM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.s16),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        indent: dividerIndent,
                        color: scheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                    ),
                    child: children[i],
                  ),
                ],
              ],
            ),
          ),
        if (footnote != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(
              footnote!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The fill a grouped surface sits on.
///
/// Light goes *up* to white and dark goes *up* to the first container step:
/// in both directions the group is one perceptible step nearer the reader
/// than the page, which is the whole job. Shared so a screen that has to
/// build its own grouped block by hand — the dashboard hero, the quick
/// actions — matches the lists around it exactly.
Color groupSurfaceColor(ColorScheme scheme) {
  return scheme.brightness == Brightness.light
      ? scheme.surfaceContainerLowest
      : scheme.surfaceContainerLow;
}

/// The vertical rhythm between two groups. One value, so the page does not
/// drift as screens are edited.
const double appGroupGap = AppSpacing.s24;
