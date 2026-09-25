import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

enum AppSectionEmphasis {
  /// A quiet name over a part of a form or a settings list. It organises; the
  /// fields are what the eye should land on.
  label,

  /// The title of a block of content — "Precisa de atenção", "Próximos
  /// cuidados", "Em dia". What almost every section on a content screen is.
  title,
}

/// The name of a block on a screen, with room for its own action.
///
/// Sentence case, not caps: pt-BR section names are long enough that
/// "PRECISAM DE ATENÇÃO" reads as an alarm rather than as a heading. The
/// action on the right is a link in the accent — "Ver todos" — and never a
/// button: the block is not the screen's main action.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.count,
    this.emphasis = AppSectionEmphasis.title,
    this.padding,
  });

  final String title;

  /// One quiet line explaining the block, when the name is not enough.
  final String? subtitle;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shown beside the name. Only worth it when the number is the reason the
  /// block exists — how many are late, not how many exist.
  final int? count;

  final AppSectionEmphasis emphasis;

  /// Overrides the space around the header.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = switch (emphasis) {
      AppSectionEmphasis.label => theme.textTheme.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      AppSectionEmphasis.title => theme.textTheme.titleMedium,
    };

    return Padding(
      padding:
          padding ??
          EdgeInsets.only(
            left: AppSpacing.s4,
            bottom: emphasis == AppSectionEmphasis.label
                ? AppSpacing.s8
                : AppSpacing.s12,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(
                      text: title,
                      children: [
                        if (count != null)
                          TextSpan(
                            text: '  $count',
                            style: titleStyle?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    style: titleStyle,
                  ),
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(width: AppSpacing.s8),
                AppSectionAction(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// The link at the right of a section header: "Ver todos".
///
/// Its tap area reaches 48dp tall without moving the header: the padding is
/// drawn outside the header's own line.
class AppSectionAction extends StatelessWidget {
  const AppSectionAction({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final color = onPressed == null
        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
        : scheme.primary;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Transform.translate(
        // Pulls the ink back to the gutter so the text lines up with the
        // edge of the card below, and the padding still counts as target.
        offset: const Offset(AppSpacing.s8, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppRadius.borderS,
            highlightColor: tones.overlayPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s8,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
