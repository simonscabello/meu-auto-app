import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration long = Duration(milliseconds: 420);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;

  /// How far a pressable surface shrinks under a finger. Small on purpose: a
  /// tile that visibly bounces is a game, one that settles is a control.
  static const double pressScale = 0.975;

  /// Zero when the user asked to reduce motion.
  static Duration of(BuildContext context, Duration preferred) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Duration.zero;
    }
    return preferred;
  }
}
