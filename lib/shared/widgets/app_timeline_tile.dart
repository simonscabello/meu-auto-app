import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

/// One event on the vehicle's timeline: a node on a rail, not a card.
///
/// History is a sequence, and a sequence drawn as a stack of separate boxes
/// throws away the one thing it has to say — that these things happened in
/// order, to the same car. The rail is what carries that, so it is drawn as
/// the content's own left border rather than as a sibling widget: the border
/// takes the height of the text beside it for free, at any font scale, with
/// no `IntrinsicHeight` in a scrolling list.
class AppTimelineTile extends StatelessWidget {
  const AppTimelineTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.isLast = false,
    this.accent,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Ends the rail. The last event of a day group has nothing below it.
  final bool isLast;

  final Color? accent;

  /// Where the rail sits, measured from the tile's left edge.
  static const double _railX = 9;
  static const double _nodeSize = 9;

  /// Distance from the top of the tile to the centre of the node. Tuned to
  /// land on the cap height of [title] at the default text scale, and the
  /// node stays near the first line as the scale grows because the padding
  /// above it is fixed.
  static const double _nodeTop = 15;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final railColor = scheme.outlineVariant;
    final nodeColor = accent ?? scheme.primary;

    final content = Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.s20,
        top: AppSpacing.s8,
        bottom: AppSpacing.s16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: AppSpacing.s8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.s12),
            trailing!,
          ],
        ],
      ),
    );

    final railed = Padding(
      padding: const EdgeInsets.only(left: _railX),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(left: BorderSide(color: railColor, width: 1.5)),
        ),
        child: content,
      ),
    );

    final stacked = Stack(
      children: [
        railed,
        Positioned(
          left: _railX + 0.75 - _nodeSize / 2,
          top: _nodeTop,
          child: Container(
            width: _nodeSize,
            height: _nodeSize,
            decoration: BoxDecoration(
              color: nodeColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) {
      return stacked;
    }

    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderS,
          child: stacked,
        ),
      ),
    );
  }
}
