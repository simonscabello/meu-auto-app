import 'package:flutter/painting.dart';

/// Spacing scale on a 4dp grid.
abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// The side gutter of every screen. One value, so the edge of a card on
  /// Início lines up with the edge of a field on a form.
  static const double page = 20;

  /// Between two blocks on a page — a header and a group, two groups.
  static const double block = 28;

  /// The padding of a scrolling screen: the gutter on the sides, a little at
  /// the top under the app bar, and room at the bottom to scroll the last
  /// row clear of the thumb.
  static const EdgeInsets screen = EdgeInsets.fromLTRB(page, s8, page, s40);

  /// The same, for a screen that starts with a heading rather than a group.
  static const EdgeInsets screenHeaded = EdgeInsets.fromLTRB(
    page,
    s16,
    page,
    s40,
  );

  static const double minTapTarget = 48;
  static const double maxContentWidth = 640;
}
