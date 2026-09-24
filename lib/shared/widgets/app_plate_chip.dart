import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';

/// The plate, drawn as a plate.
///
/// One of the few outlines in the app, and it earns it: a Brazilian plate is
/// a physical object with a border, and the outline is what makes seven
/// characters read as one at a glance. Tracking is wide for the same reason.
class AppPlateChip extends StatelessWidget {
  const AppPlateChip({super.key, required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderXs,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        plate,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: AppTypography.tabular,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}
