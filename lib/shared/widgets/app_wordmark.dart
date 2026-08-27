import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_typography.dart';

/// The product name, set as a mark.
///
/// This is typography, not artwork: there is no logo and none is invented
/// here. What makes it a mark rather than a label is the pair — `Meu` in the
/// quiet neutral, `Auto` in the brand teal — set tighter than body copy. When
/// a drawn logo exists it replaces this widget and nothing else changes.
///
/// Screen readers get the two spans as one string, "Meu Auto", because that is
/// what it is.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.size = AppWordmarkSize.medium});

  final AppWordmarkSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = switch (size) {
      AppWordmarkSize.medium => theme.textTheme.headlineMedium,
      AppWordmarkSize.large => theme.textTheme.displaySmall,
    };
    final style = base?.copyWith(
      letterSpacing: -0.5,
      fontFeatures: AppTypography.tabular,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Meu',
            style: style?.copyWith(
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextSpan(
            text: ' Auto',
            style: style?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

enum AppWordmarkSize { medium, large }
