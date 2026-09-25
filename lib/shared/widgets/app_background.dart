import 'package:flutter/material.dart';

/// The page behind every screen: one flat tone.
///
/// It used to be a vertical gradient with a radial light in the top-right
/// corner. Every screen carried the same glow, so it stopped being
/// atmosphere and became a watermark — and a light painted behind the content
/// competes with the one thing on the page that should be bright, the
/// content. Hierarchy now comes from the type and the surfaces.
///
/// Kept as a widget so the few screens that are not an [AppScaffold] (the
/// splash) paint the same page.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
}
