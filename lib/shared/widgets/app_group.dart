import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// A label, and the rows it names, inside one surface.
///
/// The grouped list every phone already uses for settings: **the label stays
/// outside and quiet, the rows go inside one filled surface with a hairline
/// edge and hairlines between them.** It says three things a bare stack
/// cannot — these rows are one thing, this thing ends here, the label above
/// is a name and not a row.
///
/// [AppSurface] is the primitive for a *block* that is not a list. This is
/// for the list.
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
    this.dividerIndent = 48,
    this.emphasis = AppSectionEmphasis.label,
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

  /// How loud the label is. A quiet label for a grouped list; a title for a
  /// section that is the point of the screen.
  final AppSectionEmphasis emphasis;

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
                      padding: const EdgeInsets.only(left: AppSpacing.s16),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        indent: dividerIndent,
                        color: tones.divider,
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
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The fill a grouped surface sits on. Shared so a screen that has to build
/// its own grouped block by hand matches the lists around it exactly.
Color groupSurfaceColor(ColorScheme scheme) => scheme.surfaceContainerLow;

/// The vertical rhythm between two groups. One value, so the page does not
/// drift as screens are edited.
const double appGroupGap = AppSpacing.block;
