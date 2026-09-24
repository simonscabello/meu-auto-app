import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_motion.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

/// A thin bar showing how far along an interval something is.
///
/// Decorative on purpose: it is excluded from semantics because the words
/// beside it ("Faltam 4.112 km") already say the same thing exactly. It is
/// drawn only when the caller could compute a real fraction from figures the
/// server sent — a bar that guesses is worse than no bar.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 4,
  });

  /// 0 to 1. Clamped.
  final double value;

  /// The fill. Defaults to the accent; a loud status passes its own.
  final Color? color;

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = AppTones.of(context);
    final target = value.clamp(0.0, 1.0);

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: AppRadius.borderXs,
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tones.track),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: target),
              duration: AppMotion.of(context, AppMotion.long),
              curve: AppMotion.enter,
              builder: (context, fraction, _) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color ?? scheme.primary,
                        borderRadius: AppRadius.borderXs,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
