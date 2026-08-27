import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;

  static const BorderRadius borderS = BorderRadius.all(Radius.circular(s));
  static const BorderRadius borderM = BorderRadius.all(Radius.circular(m));
  static const BorderRadius borderL = BorderRadius.all(Radius.circular(l));
}
