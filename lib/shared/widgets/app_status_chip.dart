import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';

/// A status, as a small badge: the word on its tint, and a glyph when there
/// is room for one.
///
/// The word carries the meaning; the tint is the second signal. It sits
/// beside a title on a detail screen and nowhere in a list — in a list the
/// group says the state, the row says it in words, and a badge per row is
/// noise.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.status,
    this.label,
    this.showIcon = true,
  });

  final AppStatus status;

  /// Replaces the status word. For a plan whose strategy changes the wording
  /// — a tyre that has "run bastante" rather than "vencido".
  final String? label;

  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = statusColors(status, theme.brightness);
    final text = label ?? visual.label;

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: AppRadius.borderXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(visual.icon, size: 15, color: visual.foreground),
              const SizedBox(width: AppSpacing.s4),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: visual.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
