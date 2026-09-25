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

    final bottom = emphasis == AppSectionEmphasis.label
        ? AppSpacing.s8
        : AppSpacing.s12;
    final heading = Semantics(
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
    );
    final hasSubtitle = subtitle != null;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        if (hasSubtitle) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ],
    );

    if (actionLabel == null) {
      return Padding(
        padding:
            padding ?? EdgeInsets.only(left: AppSpacing.s4, bottom: bottom),
        child: text,
      );
    }

    // The link's target is 48dp tall and the title's line is about 21, so the
    // difference has to go somewhere. With a subtitle it hangs below the
    // title, beside the subtitle, and the subtitle stays 4dp under the title
    // it explains. Alone, the title is centred on the target and the space
    // under the header gives back what the target took, so the card below
    // sits as close as it does under a header with no link.
    final lineHeight = MediaQuery.textScalerOf(
      context,
    ).scale((titleStyle?.fontSize ?? 16) * (titleStyle?.height ?? 1.3));
    final overhang = ((AppSpacing.minTapTarget - lineHeight) / 2).clamp(
      0.0,
      AppSpacing.minTapTarget,
    );
    return Padding(
      padding:
          padding ??
          EdgeInsets.only(
            left: AppSpacing.s4,
            bottom: hasSubtitle ? bottom : (bottom - overhang).clamp(0, bottom),
          ),
      child: Row(
        crossAxisAlignment: hasSubtitle
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(child: text),
          const SizedBox(width: AppSpacing.s8),
          AppSectionAction(
            label: actionLabel!,
            onPressed: onAction,
            alignment: hasSubtitle ? Alignment.topCenter : Alignment.center,
          ),
        ],
      ),
    );
  }
}

/// The link at the right of a section header: "Ver todos".
///
/// Its tap area is 48dp tall; [alignment] says where the word sits in it —
/// centred on a line of its own, at the top when it has to line up with a
/// title that has a subtitle under it.
class AppSectionAction extends StatelessWidget {
  const AppSectionAction({
    super.key,
    required this.label,
    this.onPressed,
    this.alignment = Alignment.center,
  });

  final String label;
  final VoidCallback? onPressed;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final color = onPressed == null
        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
        : scheme.primary;
    return Semantics(
      // Its own node: next to a heading it would otherwise merge into
      // one announcement with it.
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
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
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTapTarget,
              ),
              child: Align(
                alignment: alignment,
                widthFactor: 1,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
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
      ),
    );
  }
}
