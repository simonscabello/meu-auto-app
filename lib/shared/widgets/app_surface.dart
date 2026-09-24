import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

/// How a surface separates itself from the page.
enum AppSurfaceVariant {
  /// No fill at all. For content that is already separated by spacing and a
  /// label — which is most content.
  none,

  /// One step off the page, with a hairline. The grouped list, the card on a
  /// detail screen, the block a section sits in.
  grouped,

  /// Two steps off the page, a stronger edge, and light along the top. For a
  /// surface that is an action — a quick action tile, the odometer button.
  raised,
}

/// A container that groups, and only when grouping is what is wanted.
///
/// In the dark, a fill alone is one step of luminance and disappears at
/// arm's length; the hairline is what gives a surface an edge, and the top
/// highlight on a raised one is what makes it read as a control rather than
/// a panel. Both come from [AppTones], never from a colour picked here.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.variant = AppSurfaceVariant.none,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.color,
    this.outlined = false,
    this.borderRadius,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final AppSurfaceVariant variant;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Overrides the fill. Used by status-tinted surfaces, which take their
  /// colour from `statusColors` rather than from the scheme.
  final Color? color;

  /// Draws the hairline on a [AppSurfaceVariant.none] surface — a plate, a
  /// dashed drop zone — where there is nothing else to separate it.
  final bool outlined;

  final BorderRadius? borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = AppTones.of(context);
    final radius = borderRadius ?? AppRadius.borderM;
    final fill =
        color ??
        switch (variant) {
          AppSurfaceVariant.none => null,
          AppSurfaceVariant.grouped => scheme.surfaceContainerLow,
          AppSurfaceVariant.raised => scheme.surfaceContainerHigh,
        };
    final side = switch (variant) {
      AppSurfaceVariant.none => outlined ? tones.stroke : null,
      AppSurfaceVariant.grouped => tones.stroke,
      AppSurfaceVariant.raised => tones.strokeStrong,
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

    if (variant == AppSurfaceVariant.raised) {
      // Light catches the top edge. A gradient from the highlight to nothing
      // over the first few pixels, drawn behind the content.
      content = Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(color: tones.highlight),
            ),
          ),
          content,
        ],
      );
    }

    final decoration = BoxDecoration(
      color: fill,
      borderRadius: radius,
      border: side == null ? null : Border.all(color: side),
    );

    if (onTap == null && onLongPress == null) {
      return Container(
        clipBehavior: clipBehavior,
        decoration: decoration,
        child: content,
      );
    }

    // The ink has to be clipped to the same radius, or a ripple squares off
    // the corners of a rounded fill. The border is painted over the ink so
    // the edge stays crisp while pressed.
    return Container(
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(color: fill, borderRadius: radius),
      foregroundDecoration: side == null
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: side),
            ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          highlightColor: tones.overlayPressed,
          child: content,
        ),
      ),
    );
  }
}
