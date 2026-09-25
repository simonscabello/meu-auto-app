import 'package:flutter/widgets.dart';

/// Marks a widget as a row that pads itself inside an [AppGroup].
///
/// A group used to pad every child from the outside, which put each row's
/// ink — its pressed and hovered state — 16dp in from the card's edges: a
/// small grey island floating inside the card instead of the whole line
/// lighting up. A row that mixes this in is handed the group's padding
/// through [AppGroupScope] and applies it *inside* its own tap target, so the
/// ink runs edge to edge and the text stays where it was.
///
/// Anything else a group holds — a sentence, a button, a private row that
/// has not opted in — is still padded from the outside, exactly as before.
mixin GroupedRow on Widget {}

/// The horizontal padding a [GroupedRow] applies inside itself when it sits
/// in a group. Absent anywhere else, where a row is laid on the page and the
/// page's gutter already frames it.
class AppGroupScope extends InheritedWidget {
  const AppGroupScope({
    super.key,
    required this.horizontalPadding,
    required super.child,
  });

  final double horizontalPadding;

  /// The padding a row should apply inside its tap target: the group's, or
  /// nothing outside a group.
  static EdgeInsets paddingOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppGroupScope>();
    if (scope == null) return EdgeInsets.zero;
    return EdgeInsets.symmetric(horizontal: scope.horizontalPadding);
  }

  @override
  bool updateShouldNotify(AppGroupScope oldWidget) =>
      horizontalPadding != oldWidget.horizontalPadding;
}
