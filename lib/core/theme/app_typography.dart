import 'package:flutter/material.dart';

/// The text face. Inter, bundled, so the app reads the same on both phones —
/// one Meu Auto, not a Roboto one and an SF one.
const String kAppFontFamily = 'Inter';

/// The instrument face. Rajdhani, for the few figures that are read the way
/// a cluster is read: the odometer, a cost total, a mileage on a sheet. It is
/// never used for running text.
const String kInstrumentFontFamily = 'Rajdhani';

abstract final class AppTypography {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// A figure set as an instrument reading.
  ///
  /// [size] is the font size; the weight is bold, the figures tabular, and
  /// the tracking slightly tight so seven digits read as one number.
  static TextStyle instrument({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w700,
  }) {
    return TextStyle(
      fontFamily: kInstrumentFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: 1.0,
      letterSpacing: size >= 40 ? -1.0 : -0.25,
      color: color,
      fontFeatures: tabular,
    );
  }

  /// A small uppercase kicker: "QUILOMETRAGEM ATUAL", "PRÓXIMOS CUIDADOS".
  /// Widgets uppercase the string themselves; this only sets the type.
  static TextStyle kicker(ColorScheme colors) {
    return TextStyle(
      fontFamily: kAppFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.33,
      letterSpacing: 1.1,
      color: colors.onSurfaceVariant,
      fontFeatures: tabular,
    );
  }

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
        size: 56,
        weight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -1.5,
      ),
      displayMedium: style(
        size: 44,
        weight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -1,
      ),
      displaySmall: style(
        size: 36,
        weight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.8,
      ),
      headlineLarge: style(
        size: 32,
        weight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.6,
      ),
      headlineMedium: style(
        size: 28,
        weight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.4,
      ),
      headlineSmall: style(
        size: 24,
        weight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
      ),
      titleLarge: style(
        size: 22,
        weight: FontWeight.w600,
        height: 1.27,
        letterSpacing: -0.2,
      ),
      titleMedium: style(size: 17, weight: FontWeight.w600, height: 1.4),
      titleSmall: style(size: 15, weight: FontWeight.w600, height: 1.4),
      bodyLarge: style(size: 16, weight: FontWeight.w400, height: 1.5),
      bodyMedium: style(size: 14, weight: FontWeight.w400, height: 1.45),
      bodySmall: style(
        size: 12,
        weight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.1,
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
        letterSpacing: 0.4,
      ),
      labelSmall: style(
        size: 11,
        weight: FontWeight.w600,
        height: 1.45,
        letterSpacing: 0.6,
      ),
    );
  }
}
