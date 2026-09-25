import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

/// How a surface separates itself from the page.
enum AppSurfaceVariant {
  /// No fill at all. For content that is already separated by spacing and a
  /// title — which is most content.
  none,

  /// **The card.** One step off the page, with a hairline. A group of rows,
  /// the facts of a record, a quick action.
  grouped,

  /// A step further off the page: something that sits on top of a card or a
  /// sheet and must still read as its own object.
  raised,

  /// A step *into* the page, with no edge: the placeholder where a section
  /// has nothing yet ("Nenhum item registrado"), a block of supporting text
  /// inside a screen that already has cards. Another outline there would be
  /// noise.
  sunken,
}

/// A container that groups, and only when grouping is what is wanted.
///
/// No shadow on any variant: a card on a list does not float, it *is* the
/// list. What separates it from the page is its fill, with a hairline to help
/// in the dark where one step of luminance is subtle. The only things in the
/// app with a shadow are the ones that really float over the content — a
/// sheet, a menu, a snack bar.
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
    this.borderColor,
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
  /// drop zone — where there is nothing else to separate it.
  final bool outlined;

  /// Overrides the edge. A surface that carries a state (a late item) may
  /// take the status colour here, at low strength.
  final Color? borderColor;

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
          AppSurfaceVariant.raised => scheme.surfaceContainer,
          AppSurfaceVariant.sunken => scheme.surfaceContainer,
        };
    final side =
        borderColor ??
        switch (variant) {
          AppSurfaceVariant.none => outlined ? tones.stroke : null,
          AppSurfaceVariant.grouped => tones.stroke,
          AppSurfaceVariant.raised => tones.stroke,
          AppSurfaceVariant.sunken => null,
        };

    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.inset),
      child: child,
    );

    if (onTap != null) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        child: content,
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
          splashColor: tones.overlayPressed,
          child: content,
        ),
      ),
    );
  }
}
