import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

/// Centres [child] in the space available, and scrolls once it stops fitting.
///
/// Two things depend on the scroll and both were quietly broken without it:
/// at a large accessibility font the action button fell off the bottom with
/// nothing to reach it with, and `RefreshIndicator` needs a scrollable child,
/// so pull-to-refresh did nothing on exactly the screens where someone is
/// most likely to pull — the empty one, and the one showing an error.
///
/// [AlwaysScrollableScrollPhysics] is deliberate: the gesture has to be
/// available even when the content already fits, or the refresh only works on
/// tall phones.
class AppCenteredScroll extends StatelessWidget {
  const AppCenteredScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Unbounded height means an ancestor is already a scrollable — a card
        // in a list, a sheet, the design gallery. Adding a second scroll view
        // there is an infinite-height assertion, not a nicety.
        if (!constraints.hasBoundedHeight) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Center(child: child),
          );
        }
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppSpacing.s48,
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
