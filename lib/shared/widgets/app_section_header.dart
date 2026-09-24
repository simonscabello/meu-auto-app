import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

enum AppSectionEmphasis {
  /// A quiet name above a grouped list: `labelLarge`, muted. It organises;
  /// the rows are what the eye should land on.
  label,

  /// A section that is the point of the screen — "Próximos cuidados" on
  /// Início. `titleMedium`, in the text colour.
  title,
}

/// The label above a group of rows, or the title of a section.
///
/// Sentence case, not caps: pt-BR section names are long enough that
/// "PRECISAM DE ATENÇÃO" reads as an alarm rather than as a heading. The
/// action on the right is a link in the accent with a chevron — "Ver todos ›"
/// — and never a button.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.count,
    this.emphasis = AppSectionEmphasis.label,
  });

  final String title;

  /// One quiet line explaining the group, when the name is not enough.
  final String? subtitle;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shown beside the label. Only worth it when the number is the reason the
  /// group exists — how many are late, not how many exist.
  final int? count;

  final AppSectionEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = switch (emphasis) {
      AppSectionEmphasis.label => theme.textTheme.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
        letterSpacing: 0.2,
      ),
      AppSectionEmphasis.title => theme.textTheme.titleMedium,
    };

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: AppSpacing.s4,
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
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The link at the right of a section header: "Ver todos ›".
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.borderS,
          highlightColor: tones.overlayPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: AppSpacing.s4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 18, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
