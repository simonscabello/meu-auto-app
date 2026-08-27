import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration long = Duration(milliseconds: 400);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;

  /// Zero when the user asked to reduce motion.
  static Duration of(BuildContext context, Duration preferred) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Duration.zero;
    }
    return preferred;
  }
}
