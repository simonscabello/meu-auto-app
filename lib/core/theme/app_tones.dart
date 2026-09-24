import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_colors.dart';

/// The colours a `ColorScheme` has no slot for.
///
/// Material's scheme names roles, not atmosphere. The background gradient,
/// the glow behind the header, the hairline that gives a surface its edge and
/// the fill of an icon well are all part of the identity and none of them is
/// a scheme role — so they live here, as a theme extension, and every widget
/// reads them through [AppTones.of] rather than picking a colour of its own.
@immutable
final class AppTones extends ThemeExtension<AppTones> {
  const AppTones({
    required this.pageTop,
    required this.pageBottom,
    required this.glow,
    required this.stroke,
    required this.strokeStrong,
    required this.highlight,
    required this.iconWell,
    required this.track,
    required this.accentSoft,
    required this.divider,
    required this.overlayPressed,
    required this.accent,
  });

  /// The page, from the top down. A vertical gradient so the top of a screen
  /// is one tone warmer than the bottom — the way a dashboard is lit from
  /// above, not a flat sheet of colour.
  final Color pageTop;
  final Color pageBottom;

  /// The radial light behind the top-right corner of every screen. Drawn at a
  /// low alpha; it is atmosphere, never a shape.
  final Color glow;

  /// The hairline around a grouped surface. What separates a card from the
  /// page in the dark, where fill alone is one step of luminance.
  final Color stroke;

  /// A stronger edge for a surface that is an action — a quick action tile,
  /// the odometer button.
  final Color strokeStrong;

  /// A one-pixel lighter line along the top of a raised surface. The
  /// "metallic" cue: light catching an edge.
  final Color highlight;

  /// The fill behind an icon in a row or a card.
  final Color iconWell;

  /// The track a progress bar sits in.
  final Color track;

  /// The accent at a tint strength — an icon well for an accent icon, the
  /// selected segment of a control.
  final Color accentSoft;

  /// The line between rows inside one surface.
  final Color divider;

  /// Ink on a dark surface: a pressed row or tile.
  final Color overlayPressed;

  /// The accent itself, for the rare place that reads it outside the scheme.
  final Color accent;

  static const AppTones dark = AppTones(
    pageTop: Color(0xFF0A1B30),
    pageBottom: Color(0xFF050B14),
    glow: Color(0xFF0C8BFF),
    stroke: Color(0x4D3D5A7A),
    strokeStrong: Color(0x8A2E5B8A),
    highlight: Color(0x1FFFFFFF),
    iconWell: Color(0xFF132840),
    track: Color(0xFF17304A),
    accentSoft: Color(0x2622B8FF),
    divider: Color(0x4D1F3652),
    overlayPressed: Color(0x1F22B8FF),
    accent: AppColors.electric,
  );

  static const AppTones light = AppTones(
    pageTop: Color(0xFFF4F8FC),
    pageBottom: Color(0xFFE8EFF6),
    glow: Color(0xFF22B8FF),
    stroke: Color(0x80C3D0DD),
    strokeStrong: Color(0xB3A9BCCF),
    highlight: Color(0xB3FFFFFF),
    iconWell: Color(0xFFDCE5EE),
    track: Color(0xFFD8E2EC),
    accentSoft: Color(0x1F0A66C2),
    divider: Color(0x99C3D0DD),
    overlayPressed: Color(0x140A66C2),
    accent: AppColors.electricDeep,
  );

  static AppTones of(BuildContext context) {
    final tones = Theme.of(context).extension<AppTones>();
    if (tones != null) return tones;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  AppTones copyWith({
    Color? pageTop,
    Color? pageBottom,
    Color? glow,
    Color? stroke,
    Color? strokeStrong,
    Color? highlight,
    Color? iconWell,
    Color? track,
    Color? accentSoft,
    Color? divider,
    Color? overlayPressed,
    Color? accent,
  }) {
    return AppTones(
      pageTop: pageTop ?? this.pageTop,
      pageBottom: pageBottom ?? this.pageBottom,
      glow: glow ?? this.glow,
      stroke: stroke ?? this.stroke,
      strokeStrong: strokeStrong ?? this.strokeStrong,
      highlight: highlight ?? this.highlight,
      iconWell: iconWell ?? this.iconWell,
      track: track ?? this.track,
      accentSoft: accentSoft ?? this.accentSoft,
      divider: divider ?? this.divider,
      overlayPressed: overlayPressed ?? this.overlayPressed,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppTones lerp(ThemeExtension<AppTones>? other, double t) {
    if (other is! AppTones) return this;
    return AppTones(
      pageTop: Color.lerp(pageTop, other.pageTop, t)!,
      pageBottom: Color.lerp(pageBottom, other.pageBottom, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      strokeStrong: Color.lerp(strokeStrong, other.strokeStrong, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      iconWell: Color.lerp(iconWell, other.iconWell, t)!,
      track: Color.lerp(track, other.track, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      overlayPressed: Color.lerp(overlayPressed, other.overlayPressed, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}
