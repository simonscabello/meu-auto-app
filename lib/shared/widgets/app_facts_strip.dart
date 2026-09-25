import 'package:flutter/material.dart';
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
/// value that does not fit its column shrinks a little instead.
class AppFactsStrip extends StatelessWidget {
  const AppFactsStrip({super.key, required this.facts});

  final List<AppFact> facts;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return AppSurface(
      variant: AppSurfaceVariant.grouped,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: tones.divider),
              Expanded(child: _FactCell(fact: facts[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactCell extends StatelessWidget {
  const _FactCell({required this.fact});

  final AppFact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final valueStyle = AppTypography.figure(size: 19, color: scheme.onSurface);
    final unitStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
    );

    return Semantics(
      label: '${fact.label}: ${fact.value}${fact.unit == null ? '' : ' ${fact.unit}'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fact.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: fact.value,
                  style: valueStyle,
                  children: [
                    if (fact.unit != null)
                      TextSpan(text: ' ${fact.unit}', style: unitStyle),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
