import 'package:flutter/material.dart';

/// Radius scale.
///
/// Four steps, and each has a job: [xs] for bars and small indicators, [s]
/// for chips, badges and inline controls, [m] for cards, groups and fields,
/// [l] for sheets, dialogs and the hero surfaces. Deliberately not rounder:
/// a container that is a capsule reads as a toy, and this is an instrument.
abstract final class AppRadius {
  static const double xs = 4;
  static const double s = 10;
  static const double m = 16;
  static const double l = 22;

  /// Pills: segmented controls, filter chips and status badges only.
  static const double pill = 999;

  static const BorderRadius borderXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderS = BorderRadius.all(Radius.circular(s));
  static const BorderRadius borderM = BorderRadius.all(Radius.circular(m));
  static const BorderRadius borderL = BorderRadius.all(Radius.circular(l));
  static const BorderRadius borderPill = BorderRadius.all(
    Radius.circular(pill),
  );
}
