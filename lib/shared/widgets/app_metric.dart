import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';

class AppMetric extends StatelessWidget {
  const AppMetric({
    super.key,
    required this.value,
    this.label = '',
    this.unit,
  });

  final String value;
  final String label;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberStyle = theme.textTheme.headlineLarge?.copyWith(
      fontFeatures: AppTypography.tabular,
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
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
            ],
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
