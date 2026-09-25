import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/core/theme/app_typography.dart';

/// The plate, drawn as a plate.
///
/// A Brazilian plate is a physical object every owner knows by sight: seven
/// characters in a frame, under the blue band of the Mercosul format. The
/// chip keeps exactly that much of it — the frame and a thin band in the
/// accent — and nothing more, which is enough for "QAF5G33" to read as a
/// plate at a glance rather than as a code. It is the one automotive object
/// the app draws, because it needs no photograph of the car to be right.
class AppPlateChip extends StatelessWidget {
  const AppPlateChip({super.key, required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    return Semantics(
      label: 'Placa $plate',
      excludeSemantics: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderXs,
          border: Border.all(color: tones.strokeStrong),
          color: scheme.surfaceContainerLow,
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: scheme.primary),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4 / 2,
                ),
                child: Text(
                  plate.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabular,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
