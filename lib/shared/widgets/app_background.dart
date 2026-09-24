import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

/// The page behind every screen: a vertical gradient with one soft light
/// in the top-right corner.
///
/// This is the whole atmosphere of the app and it is deliberately quiet —
/// two gradients, no texture, no image. It is drawn once per screen by
/// [AppScaffold]; nothing else should paint a page colour.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tones.pageTop, tones.pageBottom],
            ),
          ),
        ),
        // The light. Off the corner so its centre is never on screen: what is
        // visible is the falloff, which reads as a source outside the frame.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.15, -1.05),
              radius: 1.05,
              colors: [
                tones.glow.withValues(alpha: dark ? 0.30 : 0.16),
                tones.glow.withValues(alpha: 0),
              ],
              stops: const [0, 1],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
