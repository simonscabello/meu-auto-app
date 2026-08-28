import 'package:flutter/material.dart';

/// Radius scale.
///
/// Four steps, and each has a job: [xs] for indicators and bars, [s] for
/// chips and inline controls, [m] for grouped surfaces, [l] for sheets. A
/// container that is not one of those is using the wrong one.
abstract final class AppRadius {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;

  /// Pills: segmented controls and filter chips. Deliberately not available
  /// as a container radius — a pill-shaped card is how an interface starts
  /// looking like a toy.
  static const double pill = 999;

  static const BorderRadius borderXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderS = BorderRadius.all(Radius.circular(s));
  static const BorderRadius borderM = BorderRadius.all(Radius.circular(m));
  static const BorderRadius borderL = BorderRadius.all(Radius.circular(l));
  static const BorderRadius borderPill = BorderRadius.all(
    Radius.circular(pill),
  );
}
