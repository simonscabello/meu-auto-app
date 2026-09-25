import 'package:flutter/widgets.dart';

/// Radius scale.
///
/// **The radius follows the size of the thing.** A badge of 22dp and a card of
/// 120dp with the same corner is what gives a screen the look of a template;
/// here the corner grows with the element, and anything inside something else
/// has the smaller corner, so nested shapes fit rather than collide:
/// sheet (24) > card (16) > control (12) > chip (10) > badge (6).
///
/// Nothing is rounder than a sheet. A capsule-shaped card reads as a toy, and
/// this is a tool.
abstract final class AppRadius {
  /// Badges, bars, the plate — things about 20dp tall.
  static const double xs = 6;

  /// Chips and small controls, ~32–40dp.
  static const double s = 10;

  /// Buttons, fields and segmented controls — what the thumb presses.
  static const double control = 12;

  /// Cards and groups.
  static const double m = 16;

  /// The 64dp tile an empty or error state draws its glyph on.
  static const double tile = 20;

  /// Sheets and dialogs, and only those.
  static const double l = 24;

  /// Pills: status badges and the navigation indicator.
  static const double pill = 999;

  static const BorderRadius borderXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderS = BorderRadius.all(Radius.circular(s));
  static const BorderRadius borderControl = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius borderM = BorderRadius.all(Radius.circular(m));
  static const BorderRadius borderL = BorderRadius.all(Radius.circular(l));
  static const BorderRadius borderPill = BorderRadius.all(
    Radius.circular(pill),
  );
}
