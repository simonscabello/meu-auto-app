import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

/// How a surface separates itself from the page.
enum AppSurfaceVariant {
  /// No fill at all. The default for content that is already separated by
  /// spacing and a section label — which is most content.
  none,

  /// A quiet fill, one step off the page. Groups things that belong together.
  grouped,

  /// A stronger fill for something that has to be reached for: the one row
  /// on a screen that is an action rather than a reading.
  raised,
}

/// A container that groups, and only when grouping is what is wanted.
///
/// This replaces the old `AppCard`, which put an outlined box around every
/// piece of information in the app and so stopped meaning anything. Three
/// rules follow, and they are the point of the widget:
///
///  * **No border.** Separation comes from fill, spacing and type. An outline
///    is reserved for the one case a fill cannot express — see [outlined].
///  * **The default is [AppSurfaceVariant.none].** Reaching for a fill is a
///    decision; not reaching for one is free.
///  * A tap target is at least [AppSpacing.minTapTarget] tall, always.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.variant = AppSurfaceVariant.none,
    this.padding,
    this.onTap,
    this.color,
    this.outlined = false,
    this.borderRadius,
  });

  final Widget child;
  final AppSurfaceVariant variant;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Overrides the fill. Used by status-tinted surfaces, which take their
  /// colour from `statusColors` rather than from the scheme.
  final Color? color;

  /// Draws the outline. The one legitimate use is a surface whose fill is the
  /// same as the page behind it — a plate, a dashed drop zone — where there
  /// is nothing else to separate it.
  final bool outlined;

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? AppRadius.borderM;
    final fill =
        color ??
        switch (variant) {
          AppSurfaceVariant.none => null,
          AppSurfaceVariant.grouped => scheme.surfaceContainerLow,
          AppSurfaceVariant.raised => scheme.surfaceContainerHigh,
        };

    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.s16),
      child: child,
    );

    if (onTap != null) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        child: content,
      );
    }

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: outlined
            ? Border.all(color: scheme.outlineVariant)
            : null,
      ),
      child: content,
    );

    if (onTap == null) {
      return decorated;
    }

    // The ink has to be clipped to the same radius, or a ripple squares off
    // the corners of a rounded fill.
    return Material(
      color: fill ?? Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: outlined
            ? DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}
