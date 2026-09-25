import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// One fact of an [AppFactsStrip]: a small label over its value.
@immutable
class AppFact {
  const AppFact({required this.label, required this.value, this.unit});

  final String label;

  /// The figure or the short word — "139.011", "21/09", "Gasolina".
  final String value;

  /// Set smaller and muted beside [value]: "km", "L", "km/L".
  final String? unit;
}

/// The two to four facts that answer a detail screen's first question, in
/// one strip.
///
/// A service is *when*, *at what mileage* and *how much*; a fill is *how
/// many litres*, *at what price* and *what it came to*. Those facts used to be
/// a column of label/value rows, one per line — six lines to read three
/// numbers. Here they are one card with equal columns split by hairlines:
/// one object, read across in one glance, the way a cluster shows speed and
/// range side by side.
///
/// **Nothing is cut with an ellipsis.** "139.0…" does not say the mileage. A
/// value that does not fit its column shrinks a little instead — **all the
/// values by the same factor**, so the strip still reads as one row of
/// figures. Each cell used to shrink on its own, and "R$ 240,58" sat a size
/// below "37,65 L" beside it. With the system text enlarged past
/// [stackAbove], the columns give way to one fact per line, so the size the
/// person asked for is the size they get.
class AppFactsStrip extends StatelessWidget {
  const AppFactsStrip({super.key, required this.facts});

  final List<AppFact> facts;

  /// The text scale from which the facts are read down instead of across.
  static const double stackAbove = AppTypography.largeTextScale;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final theme = Theme.of(context);
    if (MediaQuery.textScalerOf(context).scale(1) > stackAbove) {
      return AppSurface(
        variant: AppSurfaceVariant.grouped,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.inset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0) Divider(height: 1, color: tones.divider),
              Semantics(
                label: _spoken(facts[i]),
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                  // The label over the value, both the full width: side by
                  // side, half a 360dp line broke "21/03/2026" after "202".
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facts[i].label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        facts[i].unit == null
                            ? facts[i].value
                            : '${facts[i].value}$nbsp${facts[i].unit}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }
    // Measured above the strip: the row inside needs [IntrinsicHeight] for
    // its dividers, and a [LayoutBuilder] cannot sit under one.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            (constraints.maxWidth - (facts.length - 1)) / facts.length -
            _FactCell.padding * 2;
        final scale = _sharedScale(context, cell);
        return AppSurface(
          variant: AppSurfaceVariant.grouped,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < facts.length; i++) ...[
                  if (i > 0) VerticalDivider(width: 1, color: tones.divider),
                  Expanded(
                    child: _FactCell(fact: facts[i], scale: scale),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// The one factor every value is set at: the largest that lets the widest
  /// of them fit its column, never above 1.
  double _sharedScale(BuildContext context, double cellWidth) {
    if (!cellWidth.isFinite || cellWidth <= 0) return 1;
    var scale = 1.0;
    for (final fact in facts) {
      final painter = TextPainter(
        text: _FactCell.valueSpan(context, fact, 1),
        textDirection: Directionality.of(context),
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
      if (painter.width > cellWidth) {
        final fit = cellWidth / painter.width;
        if (fit < scale) scale = fit;
      }
      painter.dispose();
    }
    return scale;
  }
}

class _FactCell extends StatelessWidget {
  const _FactCell({required this.fact, required this.scale});

  static const double padding = AppSpacing.s12;

  final AppFact fact;

  /// Shared by every cell of the strip; see [AppFactsStrip._sharedScale].
  final double scale;

  /// The value and its unit at the system text size times [scale]. The
  /// sizes are final, so the text is laid out with no further scaling.
  static TextSpan valueSpan(BuildContext context, AppFact fact, double scale) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    // A figure for a number; a word ("Gasolina", "Híbrido") keeps the text
    // face — tabular digits and tight tracking are for readings.
    final numeric = RegExp(r'\d').hasMatch(fact.value);
    final valueStyle = numeric
        ? AppTypography.figure(size: 19, color: scheme.onSurface)
        : theme.textTheme.titleMedium;
    final unitStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
    );
    TextStyle? sized(TextStyle? style, double fallback) => style?.copyWith(
      fontSize: scaler.scale(style.fontSize ?? fallback) * scale,
    );
    return TextSpan(
      text: fact.value,
      style: sized(valueStyle, 19),
      children: [
        if (fact.unit != null)
          TextSpan(text: '$nbsp${fact.unit}', style: sized(unitStyle, 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: _spoken(fact),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Two lines before an ellipsis: with the system font turned up,
            // "Combustível" in a third of the width lost its end.
            Text(
              fact.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                valueSpan(context, fact, scale),
                textScaler: TextScaler.noScaling,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _spoken(AppFact fact) =>
    '${fact.label}: ${fact.value}${fact.unit == null ? '' : ' ${fact.unit}'}';
