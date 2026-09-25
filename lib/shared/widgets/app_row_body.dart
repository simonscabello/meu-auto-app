import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';

/// The words of a row: a name, one line of state, and the figure the row is
/// worth.
///
/// ```
/// Gasolina · 37,65 L ............ R$ 240,58
/// 5 set · Sem consumo ainda
/// ```
///
/// The figure sits on the name's line and never wraps; the state line runs
/// under both, the whole width of the text. It used to be a column of its
/// own beside the text, allowed up to 40% of the screen, and on a 360dp
/// phone that left "5 set · Sem consumo ainda" a column too narrow for it,
/// the "L" of "37,65 L" alone on a line, and "Consumo" broken mid-word
/// beside a phrase set as a value.
///
/// The figure moves under the words, on the text's own edge, when it would
/// take more than [maxValueShare] of the line or the text is set large
/// ([AppTypography.isLargeText]) — either way, beside the name it would
/// leave the name a column too thin to read.
///
/// [AppListRow] is built on this; a row with an interior of its own
/// ([AppListRowShell]) uses it too, so every row breaks its lines the same
/// way.
class AppRowBody extends StatelessWidget {
  const AppRowBody({
    super.key,
    required this.title,
    this.titleMaxLines,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
    this.footnote,
    this.value,
    this.strongValue = true,
  });

  /// The share of the line the figure may take beside the name.
  static const maxValueShare = 0.5;

  final String title;
  final int? titleMaxLines;

  /// Merged over the title's theme style.
  final TextStyle? titleStyle;

  final String? subtitle;

  /// Merged over the state line's theme style.
  final TextStyle? subtitleStyle;

  /// A second supporting line, under [subtitle].
  final String? footnote;

  final String? value;

  /// A figure — an amount, a total — in the text colour and tabular, rather
  /// than a quiet setting.
  final bool strongValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final valueStyle = strongValue
        ? theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: AppTypography.tabular,
          )
        : theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final supporting = theme.textTheme.bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant)
        .merge(subtitleStyle);
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final name = Text(
      title,
      maxLines: titleMaxLines,
      overflow: titleMaxLines == null ? null : TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.merge(titleStyle),
    );
    final subtitle = this.subtitle;
    final footnote = this.footnote;
    final value = this.value;

    List<Widget> under({required bool withValue}) => [
      if (subtitle != null && subtitle.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(subtitle, style: supporting),
      ],
      if (footnote != null && footnote.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(footnote, style: quiet),
      ],
      if (withValue && value != null) ...[
        const SizedBox(height: AppSpacing.s4),
        Text(value, style: valueStyle),
      ],
    ];

    if (value == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [name, ...under(withValue: false)],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final beside =
            !AppTypography.isLargeText(context) &&
            _widthOf(context, value, valueStyle) <=
                constraints.maxWidth * maxValueShare;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (beside)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: name),
                  const SizedBox(width: AppSpacing.s12),
                  Text(
                    value,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.end,
                    style: valueStyle,
                  ),
                ],
              )
            else
              name,
            ...under(withValue: !beside),
          ],
        );
      },
    );
  }

  static double _widthOf(BuildContext context, String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// The arrow at the end of a row that opens something. Fainter than the
/// supporting text: it is the least important thing on the row.
class AppRowChevron extends StatelessWidget {
  const AppRowChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right,
      size: 20,
      color: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
    );
  }
}
