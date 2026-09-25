import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_centered_scroll.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';

/// A screen with nothing on it yet.
///
/// A good empty state answers three things: what belongs here, why it is not
/// here yet, and the one thing to do now. Without the third it is a dead end.
///
/// Scrolls, and that is load-bearing: `RefreshIndicator` needs a scrollable
/// child, so pull-to-refresh works here too.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// One glyph in a large well above the title. Optional: an empty state
  /// inside a group does not want one.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCenteredScroll(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIconWell(
                icon: icon!,
                size: AppIconWellSize.xl,
                tone: AppIconWellTone.accent,
              ),
              const SizedBox(height: AppSpacing.s20),
            ],
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            // Only with both: a label with nowhere to go, or a callback with
            // no words, used to vanish silently and leave a dead end.
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.s24),
              AppButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
