import 'package:flutter/material.dart';

/// Null uses the platform typeface. Change this one constant when a brand
/// font is chosen; declare the files in `pubspec.yaml` and set the family.
const String? kAppFontFamily = null;

abstract final class AppTypography {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(ColorScheme colors) {
    TextStyle style({
      required double size,
      required FontWeight weight,
      required double height,
      double letterSpacing = 0,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: kAppFontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? colors.onSurface,
        fontFeatures: tabular,
      );
    }

    return TextTheme(
      displayLarge: style(
        size: 57,
        weight: FontWeight.w400,
        height: 1.12,
        letterSpacing: -0.25,
      ),
      displayMedium: style(size: 45, weight: FontWeight.w400, height: 1.16),
      displaySmall: style(size: 36, weight: FontWeight.w400, height: 1.22),
      headlineLarge: style(size: 32, weight: FontWeight.w600, height: 1.25),
      headlineMedium: style(size: 28, weight: FontWeight.w600, height: 1.29),
      headlineSmall: style(size: 24, weight: FontWeight.w600, height: 1.33),
      titleLarge: style(size: 22, weight: FontWeight.w600, height: 1.27),
      titleMedium: style(
        size: 16,
        weight: FontWeight.w600,
        height: 1.5,
        letterSpacing: 0.15,
      ),
      titleSmall: style(
        size: 14,
        weight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
      ),
      bodyLarge: style(
        size: 16,
        weight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.15,
      ),
      bodyMedium: style(
        size: 14,
        weight: FontWeight.w400,
        height: 1.43,
        letterSpacing: 0.25,
      ),
      bodySmall: style(
        size: 12,
        weight: FontWeight.w400,
        height: 1.33,
        letterSpacing: 0.4,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: style(
        size: 14,
        weight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
      ),
      labelMedium: style(
        size: 12,
        weight: FontWeight.w600,
        height: 1.33,
        letterSpacing: 0.5,
      ),
      labelSmall: style(
        size: 11,
        weight: FontWeight.w600,
        height: 1.45,
        letterSpacing: 0.5,
      ),
    );
  }
}
