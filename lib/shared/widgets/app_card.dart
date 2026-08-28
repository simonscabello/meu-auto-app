import 'package:flutter/material.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// A grouped surface, kept for the detail screens where a card is still the
/// right answer — one object, its facts, and nothing else on the screen.
///
/// It is no longer the default container. Lists, timelines and dashboards
/// build from rows and sections; reaching for a card there is what produced
/// a screen where an alert, a total and a nudge all looked the same. New code
/// should use [AppSurface] directly and pick a variant deliberately.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      variant: AppSurfaceVariant.grouped,
      onTap: onTap,
      padding: padding,
      child: child,
    );
  }
}
