import 'package:flutter/material.dart';

/// The two colour schemes, hand-built around one identity: a night-time
/// instrument cluster.
///
/// Dark is the primary mode. The page is a deep navy, not a grey — every
/// neutral carries blue — and the one accent is an electric blue reserved for
/// what is selected, what is a link, and what is on track. Red exists only
/// for something that is actually late.
///
/// Light is the same identity in daylight: cool, blue-biased neutrals and a
/// deeper blue so filled buttons and links stay readable on a pale page.
///
/// Every pair a screen paints is checked for WCAG AA (4.5:1) in
/// `test/core/theme/app_theme_test.dart`. Change a value here and the test
/// says whether it still reads.
abstract final class AppColors {
  /// The accent. Selected tab, links, progress, focus, the check on "em dia".
  static const Color electric = Color(0xFF22B8FF);

  /// A deeper blue for filled controls in the light theme, where the electric
  /// tone would wash out against a pale page.
  static const Color electricDeep = Color(0xFF0A66C2);

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: electric,
    onPrimary: Color(0xFF04121F),
    primaryContainer: Color(0xFF0C2E4E),
    onPrimaryContainer: Color(0xFFA6DDFF),
    secondary: Color(0xFF7F98B3),
    onSecondary: Color(0xFF0B1A2B),
    secondaryContainer: Color(0xFF1B2F45),
    onSecondaryContainer: Color(0xFFD3E1F0),
    tertiary: Color(0xFFFFC857),
    onTertiary: Color(0xFF2B1D00),
    tertiaryContainer: Color(0xFF3B2A08),
    onTertiaryContainer: Color(0xFFFFE1A0),
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF2B0606),
    errorContainer: Color(0xFF4A1616),
    onErrorContainer: Color(0xFFFFB4B4),
    surface: Color(0xFF060E18),
    onSurface: Color(0xFFF1F6FB),
    onSurfaceVariant: Color(0xFF9AAEC4),
    outline: Color(0xFF3D5A7A),
    outlineVariant: Color(0xFF1F3652),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF1C3452),
    onInverseSurface: Color(0xFFF1F6FB),
    inversePrimary: Color(0xFF0A7BD6),
    surfaceTint: electric,
    surfaceDim: Color(0xFF060E18),
    surfaceBright: Color(0xFF1B3350),
    surfaceContainerLowest: Color(0xFF030910),
    surfaceContainerLow: Color(0xFF0B1928),
    surfaceContainer: Color(0xFF0E2032),
    surfaceContainerHigh: Color(0xFF132840),
    surfaceContainerHighest: Color(0xFF17304A),
  );

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: electricDeep,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD6EAFF),
    onPrimaryContainer: Color(0xFF063A6E),
    secondary: Color(0xFF4E6A87),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD9E4F0),
    onSecondaryContainer: Color(0xFF16304A),
    tertiary: Color(0xFF8A5A00),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFE3A6),
    onTertiaryContainer: Color(0xFF3A2600),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF7A1F19),
    surface: Color(0xFFEEF3F8),
    onSurface: Color(0xFF0B1A2B),
    onSurfaceVariant: Color(0xFF44596F),
    outline: Color(0xFF6E8299),
    outlineVariant: Color(0xFFC3D0DD),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF122335),
    onInverseSurface: Color(0xFFEEF3F8),
    inversePrimary: Color(0xFF7CC4FF),
    surfaceTint: electricDeep,
    surfaceDim: Color(0xFFDCE4EC),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7FAFD),
    surfaceContainer: Color(0xFFE2E9F1),
    surfaceContainerHigh: Color(0xFFDCE5EE),
    surfaceContainerHighest: Color(0xFFD8E2EC),
  );
}
