import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_motion.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

/// One choice out of a few, all visible, one tap away.
///
/// Built rather than taken from Material because `SegmentedButton` sizes its
/// segments to their labels and then overflows when the system font is
/// scaled up — which on a settings screen means the theme picker breaks for
/// exactly the people most likely to be looking for it.
///
/// Each segment is as wide as its label plus an equal share of what is left,
/// so "Tudo" gives room to "Abastecimentos". Equal thirds used to shrink
/// "Abastecimentos" alone to about 12px on a 360dp phone while "Tudo" kept
/// 15px, and the selected label — set heavier — changed size as it was
/// tapped. When the labels do not fit even so, all of them scale down by
/// the same factor, measured at the heavier weight, so they always read as
/// one size.
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
    final tones = AppTones.of(context);
    final active = enabled && onChanged != null;
    final base = theme.textTheme.labelLarge;

    return Container(
      // 2dp of track around 44dp segments: the control is 48dp tall, and
      // every segment is a target that size with the track counted in.
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        // A step below the page in daylight: the field tone sat within one
        // percent of the page there and the track vanished.
        color: scheme.brightness == Brightness.light
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainer,
        borderRadius: AppRadius.borderControl,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _SegmentLayout.measure(
            context,
            labels: [for (final option in options) option.label],
            style: base,
            width: constraints.maxWidth,
          );
          return Row(
            children: [
              for (final (index, option) in options.indexed)
                Expanded(
                  // Widths as weights: the row divides exactly what it has,
                  // with no rounding left over to overflow by.
                  flex: (layout.widths[index] * 100).round(),
                  child: Semantics(
                    container: true,
                    button: true,
                    selected: option.value == value,
                    enabled: active,
                    label: option.label,
                    excludeSemantics: true,
                    onTap: active ? () => onChanged!(option.value) : null,
                    child: AnimatedContainer(
                      duration: AppMotion.of(context, AppMotion.short),
                      curve: AppMotion.standard,
                      decoration: BoxDecoration(
                        color: option.value == value
                            ? scheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: AppRadius.borderS,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: AppRadius.borderS,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: active ? () => onChanged!(option.value) : null,
                          highlightColor: tones.overlayPressed,
                          splashColor: tones.overlayPressed,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: _SegmentLayout.padding,
                                vertical: AppSpacing.s8,
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    option.label,
                                    maxLines: 1,
                                    // The size is already the scaled one.
                                    textScaler: TextScaler.noScaling,
                                    style: base?.copyWith(
                                      fontSize: layout.fontSize,
                                      fontWeight: option.value == value
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: option.value == value
                                          ? scheme.onPrimaryContainer
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
          );
        },
      ),
    );
  }
}

/// Segment widths and one label size for the whole control.
final class _SegmentLayout {
  const _SegmentLayout(this.widths, this.fontSize);

  /// Inside each segment, either side of the label.
  static const double padding = AppSpacing.s8;

  final List<double> widths;
  final double fontSize;

  static _SegmentLayout measure(
    BuildContext context, {
    required List<String> labels,
    required TextStyle? style,
    required double width,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final natural = scaler.scale(style?.fontSize ?? 15);
    final heavy = style?.copyWith(
      fontSize: natural,
      fontWeight: FontWeight.w600,
    );
    final direction = Directionality.of(context);
    final labelWidths = [
      for (final label in labels)
        (TextPainter(
          text: TextSpan(text: label, style: heavy),
          textDirection: direction,
          maxLines: 1,
        )..layout()).width.ceilToDouble(),
    ];
    final inner = width;
    final chrome = padding * 2 * labels.length;
    final text = labelWidths.fold<double>(0, (sum, w) => sum + w);
    if (text + chrome <= inner) {
      final share = (inner - text - chrome) / labels.length;
      return _SegmentLayout([
        for (final w in labelWidths) w + padding * 2 + share,
      ], natural);
    }
    final factor = ((inner - chrome) / text).clamp(0.0, 1.0);
    return _SegmentLayout([
      for (final w in labelWidths) w * factor + padding * 2,
    ], natural * factor);
  }
}

final class AppSegmentedOption<T> {
  const AppSegmentedOption({required this.value, required this.label});

  final T value;
  final String label;
}
