import 'package:flutter/material.dart';

/// The two colour schemes of Meu Auto.
///
/// **Graphite, not navy.** The first dark identity was a navy page with a
/// radial light in one corner and an electric cyan accent — an instrument
/// cluster drawn literally. It read as a mock-up: every screen carried the
/// same glow, the cyan sat close to neon, and the tint on every neutral made
/// the accent stop meaning anything. This one is a car's cabin at night
/// instead of its dashboard lights: charcoal neutrals with a trace of cool
/// blue, surfaces one step up from the page, and one calm signal blue.
///
/// Three rules hold the palette together, and each one has a test behind it
/// in `test/core/theme/app_theme_test.dart`:
///
/// 1. **A card is one step above the page, in both themes, by colour alone.**
///    No shadow separates a card from the page — the fill does, helped by a
///    hairline. In the dark theme that means `surfaceContainerLow` (the card)
///    is *lighter* than `surface` (the page), which is the Material ordering;
///    `surfaceContainerLowest` is the only tone below the page.
/// 2. **Every pair a screen paints reaches 4.5:1** — text, muted text, the
///    accent as text, and the text on each status tint.
/// 3. **The border of a control reaches 3:1** against what is behind it
///    (WCAG 1.4.11). `outline` is for what is touched — a field, a checkbox;
///    `outlineVariant` is the decorative hairline between blocks.
///
/// Blue is the only chromatic colour at rest. Red means late, amber means
/// close, green appears only after something finished well, and all three
/// are reserved for exactly that.
abstract final class AppColors {
  /// The accent on the dark theme: selected, a link, the one filled button.
  static const Color signal = Color(0xFF5B9DFF);

  /// The accent on the light theme — a deeper blue, so white text on a filled
  /// button and blue text on a white card both clear 4.5:1.
  static const Color signalDeep = Color(0xFF1A66DA);

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: signal,
    onPrimary: Color(0xFF04101E),
    primaryContainer: Color(0xFF16283E),
    onPrimaryContainer: Color(0xFFC9DEFF),
    // Secondary is the neutral tonal step: the "equal weight, not the main
    // thing" button and the unselected chip.
    secondary: Color(0xFF98A7BC),
    onSecondary: Color(0xFF0E1520),
    secondaryContainer: Color(0xFF232A34),
    onSecondaryContainer: Color(0xFFE3E8EF),
    // Tertiary is amber, the role of "close": something to notice, not to be
    // alarmed by.
    tertiary: Color(0xFFEFB54A),
    onTertiary: Color(0xFF241800),
    tertiaryContainer: Color(0xFF33270F),
    onTertiaryContainer: Color(0xFFFFE1A6),
    error: Color(0xFFF07070),
    onError: Color(0xFF2A0707),
    errorContainer: Color(0xFF3A1719),
    onErrorContainer: Color(0xFFFFD2D2),
    // The page.
    surface: Color(0xFF090C10),
    onSurface: Color(0xFFECEFF3),
    onSurfaceVariant: Color(0xFF98A2B0),
    surfaceDim: Color(0xFF090C10),
    surfaceBright: Color(0xFF2A313B),
    surfaceContainerLowest: Color(0xFF06080B),
    // The card.
    surfaceContainerLow: Color(0xFF161B22),
    // A field, the navigation bar, a sunken block inside a card.
    surfaceContainer: Color(0xFF1C222A),
    // A sheet's raised parts, a pressed row, a dialog.
    surfaceContainerHigh: Color(0xFF222932),
    // Tracks, unselected chips, the skeleton.
    surfaceContainerHighest: Color(0xFF2A313B),
    outline: Color(0xFF6C7888),
    outlineVariant: Color(0xFF262D37),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE6EAF0),
    onInverseSurface: Color(0xFF11151B),
    inversePrimary: signalDeep,
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: signalDeep,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCE8FD),
    onPrimaryContainer: Color(0xFF0B3470),
    secondary: Color(0xFF52606F),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE8ECF1),
    onSecondaryContainer: Color(0xFF1B2430),
    tertiary: Color(0xFF93580A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFCEFD6),
    onTertiaryContainer: Color(0xFF5E3700),
    error: Color(0xFFC4312F),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFCE4E3),
    onErrorContainer: Color(0xFF7A1614),
    surface: Color(0xFFF2F4F7),
    onSurface: Color(0xFF0F141A),
    onSurfaceVariant: Color(0xFF5A6472),
    surfaceDim: Color(0xFFE3E7EC),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF4F6F8),
    surfaceContainerHigh: Color(0xFFEBEEF2),
    surfaceContainerHighest: Color(0xFFE1E5EB),
    outline: Color(0xFF808A98),
    outlineVariant: Color(0xFFE1E5EB),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF1B2129),
    onInverseSurface: Color(0xFFEEF1F5),
    inversePrimary: signal,
    surfaceTint: Colors.transparent,
  );
}
