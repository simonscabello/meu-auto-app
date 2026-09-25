import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_colors.dart';

/// The colours a `ColorScheme` has no slot for.
///
/// Material's scheme names roles; a few of the roles this app needs are not
/// among them — the hairline between rows, the track of a gauge, the tint of
/// a pressed row, and "done", which Material has no word for. They live here,
/// as a theme extension, and every widget reads them through [AppTones.of]
/// rather than picking a colour of its own.
///
/// There is no gradient and no glow in this list on purpose. The page is one
/// flat tone; atmosphere comes from the type and the spacing, not from light
/// painted behind the content.
@immutable
final class AppTones extends ThemeExtension<AppTones> {
  const AppTones({
    required this.stroke,
    required this.strokeStrong,
    required this.iconWell,
    required this.track,
    required this.accentSoft,
    required this.divider,
    required this.overlayPressed,
    required this.accent,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
  });

  /// The hairline around a card or a group. Decorative: it helps the fill
  /// separate a card from the page, it does not delimit a control.
  final Color stroke;

  /// The edge of something that is touched and sits on the page with no fill
  /// of its own — the plate outline, an outlined button.
  final Color strokeStrong;

  /// The fill behind the one large glyph of an empty or error state.
  final Color iconWell;

  /// The groove a gauge sits in.
  final Color track;

  /// The accent at a tint strength — the selected segment, the tonal accent
  /// button, the navigation indicator.
  final Color accentSoft;

  /// The line between rows inside one group.
  final Color divider;

  /// Ink on a surface: a pressed row or tile.
  final Color overlayPressed;

  /// The accent itself, for the rare place that reads it outside the scheme.
  final Color accent;

  /// "Done". Only ever shown after something finished well — a confirmation,
  /// a paid tax — and never as decoration.
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  static const AppTones dark = AppTones(
    stroke: Color(0xFF262D37),
    strokeStrong: Color(0xFF3A4350),
    iconWell: Color(0xFF1C222A),
    track: Color(0xFF2A313B),
    accentSoft: Color(0xFF16283E),
    divider: Color(0xFF232932),
    overlayPressed: Color(0x14FFFFFF),
    accent: AppColors.signal,
    success: Color(0xFF57C38D),
    successContainer: Color(0xFF12301F),
    onSuccessContainer: Color(0xFFC6F0D8),
  );

  static const AppTones light = AppTones(
    stroke: Color(0xFFE1E5EB),
    strokeStrong: Color(0xFFC5CCD6),
    iconWell: Color(0xFFEBEEF2),
    track: Color(0xFFE1E5EB),
    accentSoft: Color(0xFFDCE8FD),
    divider: Color(0xFFE8EBF0),
    overlayPressed: Color(0x0F0F141A),
    accent: AppColors.signalDeep,
    success: Color(0xFF1D7A4A),
    successContainer: Color(0xFFDDF3E6),
    onSuccessContainer: Color(0xFF0E4A2B),
  );

  static AppTones of(BuildContext context) {
    final tones = Theme.of(context).extension<AppTones>();
    if (tones != null) return tones;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  AppTones copyWith({
    Color? stroke,
    Color? strokeStrong,
    Color? iconWell,
    Color? track,
    Color? accentSoft,
    Color? divider,
    Color? overlayPressed,
    Color? accent,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
  }) {
    return AppTones(
      stroke: stroke ?? this.stroke,
      strokeStrong: strokeStrong ?? this.strokeStrong,
      iconWell: iconWell ?? this.iconWell,
      track: track ?? this.track,
      accentSoft: accentSoft ?? this.accentSoft,
      divider: divider ?? this.divider,
      overlayPressed: overlayPressed ?? this.overlayPressed,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    );
  }

  @override
  AppTones lerp(ThemeExtension<AppTones>? other, double t) {
    if (other is! AppTones) return this;
    return AppTones(
      stroke: Color.lerp(stroke, other.stroke, t)!,
      strokeStrong: Color.lerp(strokeStrong, other.strokeStrong, t)!,
      iconWell: Color.lerp(iconWell, other.iconWell, t)!,
      track: Color.lerp(track, other.track, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      overlayPressed: Color.lerp(overlayPressed, other.overlayPressed, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
    );
  }
}
