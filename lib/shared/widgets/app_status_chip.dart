import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';

/// A status, as a small pill: the glyph, the word, and a tint.
///
/// The glyph and the word carry the meaning; the tint is the third signal,
/// never the only one. It sits beside a title on a detail screen and nowhere
/// in a list — in a list the group says the state and a pill per row is
/// noise.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({super.key, required this.status, this.label});

  final AppStatus status;

  /// Replaces the status word. For a plan whose strategy changes the wording
  /// — a tyre that has "run bastante" rather than "vencido".
  final String? label;

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
          horizontal: AppSpacing.s12,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: AppRadius.borderPill,
          border: Border.all(color: visual.foreground.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(visual.icon, size: 14, color: visual.foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: visual.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
