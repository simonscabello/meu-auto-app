import 'package:flutter/widgets.dart';

/// Spacing scale on a 4dp grid.
///
/// Values in between (10, 14, 18) do not read as different on a phone; they
/// only add variation nobody intended. When none of these fits, the layout is
/// usually what is wrong.
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

  /// The side gutter of every screen, tab header included. One value, so the
  /// title of a tab, the edge of a card and the edge of a field all start on
  /// the same line — the old tab titles sat 12dp left of their own content.
  static const double page = 20;

  /// Between two blocks on a page — a header and a group, two groups.
  static const double block = 28;

  /// Inside a card: the gap from its edge to its content.
  static const double inset = 16;

  /// The padding of a scrolling screen under an app bar: the gutter on the
  /// sides, a little at the top, and room at the bottom to scroll the last
  /// row clear of the thumb.
  static const EdgeInsets screen = EdgeInsets.fromLTRB(page, s16, page, s40);

  /// The same, for a screen whose first element is a heading.
  static const EdgeInsets screenHeaded = EdgeInsets.fromLTRB(
    page,
    s20,
    page,
    s40,
  );

  /// The padding of a tab screen, whose header lives in the body.
  static const EdgeInsets tab = EdgeInsets.fromLTRB(page, 0, page, s40);

  static const double minTapTarget = 48;

  /// Where a row's text starts when the row has a glyph: the 24dp glyph slot
  /// plus the 12dp gap after it. Hairlines between rows start here.
  static const double rowTextIndent = 36;

  /// How far a 48dp target reaches past a 36dp drawn control on each side.
  /// A header pulls such a control out by this much so the drawn edge — the
  /// avatar, the icon — meets the gutter instead of the invisible target.
  static const double targetOverhang = (minTapTarget - 36) / 2;

  /// The primary button of a form, and anything that must weigh as much.
  static const double buttonHeight = 52;

  /// A button inside a row or a card: it must not weigh as much as the
  /// screen's own action. The 48dp target stays through the padded hit area.
  static const double compactButtonHeight = 36;

  static const double maxContentWidth = 640;
}
