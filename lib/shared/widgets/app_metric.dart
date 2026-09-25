import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';

/// How much room a figure is allowed to take.
enum AppMetricSize {
  /// The one number a screen is about. One per screen, at most.
  hero,

  /// A figure standing beside others. Three heroes side by side is three
  /// numbers shouting and none of them read.
  compact,
}

/// A number with its unit and its label, set as a reading.
///
/// The unit is set in the label style and joined to the value in one
/// [Text.rich], so "34,7 L" wraps and scales as one thing rather than as a
/// number that can be separated from what it measures.
class AppMetric extends StatelessWidget {
  const AppMetric({
    super.key,
    required this.value,
    this.label = '',
    this.unit,
    this.size = AppMetricSize.hero,
    this.color,
  });

  final String value;
  final String label;
  final String? unit;
  final AppMetricSize size;

  /// Overrides the figure's colour. A loud status passes its own.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final numberStyle = AppTypography.figure(
      size: size == AppMetricSize.hero ? 34 : 22,
      color: color ?? scheme.onSurface,
    );
    final unitStyle =
        (size == AppMetricSize.hero
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: value,
            style: numberStyle,
            children: [
              if (unit != null) TextSpan(text: ' $unit', style: unitStyle),
            ],
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
