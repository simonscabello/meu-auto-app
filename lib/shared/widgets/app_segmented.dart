import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_motion.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

/// One choice out of a few, all visible, one tap away.
///
/// Built rather than taken from Material because `SegmentedButton` sizes its
/// segments to their labels and then overflows when the system font is
/// scaled up — which on a settings screen means the theme picker breaks for
/// exactly the people most likely to be looking for it. Here every segment
/// takes an equal share of the width and its label scales down inside it, so
/// three options fit a 360dp phone at any text size.
///
/// For two to four options of equal weight. More than that is a list.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<AppSegmentedOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = enabled && onChanged != null;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.borderS,
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: option.value == value,
                enabled: active,
                label: option.label,
                excludeSemantics: true,
                child: AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.short),
                  curve: AppMotion.standard,
                  decoration: BoxDecoration(
                    color: option.value == value
                        ? scheme.surfaceContainerLowest
                        : Colors.transparent,
                    borderRadius: AppRadius.borderXs,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: AppRadius.borderXs,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: active ? () => onChanged!(option.value) : null,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s4,
                            vertical: AppSpacing.s8,
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                option.label,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: option.value == value
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class AppSegmentedOption<T> {
  const AppSegmentedOption({required this.value, required this.label});

  final T value;
  final String label;
}
