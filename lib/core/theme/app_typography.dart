import 'package:flutter/material.dart';

/// The text face. Inter, bundled, so the app reads the same on both phones —
/// one Meu Auto, not a Roboto one and an SF one — and correctly from the first
/// frame, offline.
const String kAppFontFamily = 'Inter';

/// The type of Meu Auto.
///
/// One family, a scale built for this app rather than Material's, and three
/// decisions that define it:
///
/// 1. **Tracking tightens as size grows.** Large Inter set at zero tracking
///    reads loose — "Prius" at 28px looks typed, not designed. Display and
///    headline sizes pull in by about 2–3% of the size; body text gets none,
///    because tight running text tires the eye.
/// 2. **Figures are tabular only where they line up.** A mileage, a price, a
///    column of amounts: `tabular` or [figure]. Not globally — Inter's
///    tabular set also widens punctuation, and "E-mail" turned into
///    "E - mail" when every style carried it.
/// 3. **Four weights as four steps.** 400 reads, 500 names, 600 titles, 700
///    is for the few headings that open a screen. Nothing lighter, nothing
///    heavier.
///
/// The one automotive gesture is [figure]: the odometer and the totals are set
/// large, tabular and tight, the way a cluster sets a number — in the same
/// face as everything else, not in a display font that pretends to be a
/// screen.
abstract final class AppTypography {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// The system text scale past which two things stop sharing a line.
  ///
  /// At 1.6 on a 360dp phone a name and an amount side by side leave the
  /// name a column narrow enough to break "Gastos" into "Gasto / s". Past
  /// this scale a row's value, a row's button and a fact's figure go under
  /// the words instead of beside them, and the two quick actions stack.
  static const double largeTextScale = 1.3;

  /// Whether the text is enlarged past [largeTextScale].
  static bool isLargeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > largeTextScale;

  /// A number meant to be read as a reading: the odometer, a total, the
  /// figures of a fill. Tabular, tight, and one line high.
  static TextStyle figure({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: kAppFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: 1.05,
      letterSpacing: size >= 28 ? -size * 0.035 : -size * 0.01,
      color: color,
      fontFeatures: tabular,
    );
  }

  /// A small uppercase kicker. Used sparingly — the plate, the month over a
  /// run of history. Widgets uppercase the string themselves.
  static TextStyle kicker(ColorScheme colors) {
    return TextStyle(
      fontFamily: kAppFontFamily,
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0.9,
      color: colors.onSurfaceVariant,
    );
  }

  static TextTheme textTheme(ColorScheme colors) {
    TextStyle style(
      double size,
      FontWeight weight,
      double height, {
      double tracking = 0,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: kAppFontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: tracking,
        color: color ?? colors.onSurface,
      );
    }

    final muted = colors.onSurfaceVariant;

    return TextTheme(
      // --- Display: a figure standing alone. Rare. ---
      displayLarge: style(44, FontWeight.w700, 1.05, tracking: -1.4),
      displayMedium: style(38, FontWeight.w700, 1.06, tracking: -1.2),
      displaySmall: style(32, FontWeight.w700, 1.08, tracking: -0.9),

      // --- Headline: what a screen is about. ---
      headlineLarge: style(28, FontWeight.w700, 1.12, tracking: -0.8),
      headlineMedium: style(25, FontWeight.w700, 1.15, tracking: -0.6),
      headlineSmall: style(21, FontWeight.w700, 1.2, tracking: -0.4),

      // --- Title: an app bar, a section, a row. ---
      titleLarge: style(18, FontWeight.w600, 1.25, tracking: -0.25),
      titleMedium: style(16, FontWeight.w600, 1.3, tracking: -0.15),
      titleSmall: style(15, FontWeight.w500, 1.3, tracking: -0.1),

      // --- Body: what is read. No tracking. ---
      bodyLarge: style(16, FontWeight.w400, 1.45),
      bodyMedium: style(14.5, FontWeight.w400, 1.45),
      bodySmall: style(13, FontWeight.w400, 1.4, color: muted),

      // --- Label: a button, a tab, a tag. ---
      labelLarge: style(15, FontWeight.w600, 1.2),
      labelMedium: style(
        12.5,
        FontWeight.w500,
        1.3,
        tracking: 0.1,
        color: muted,
      ),
      labelSmall: style(
        11.5,
        FontWeight.w600,
        1.3,
        tracking: 0.2,
        color: muted,
      ),
    );
  }
}
