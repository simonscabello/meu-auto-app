import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

enum AppIconWellSize {
  /// Beside a settings row.
  s,

  /// Beside a list row. The default.
  m,

  /// On a tile or a header.
  l,

  /// The one glyph of an empty or error state — the only size that is drawn
  /// on a tile.
  xl,
}

/// How the glyph is tinted.
enum AppIconWellTone {
  /// The muted text colour. What almost every row carries.
  neutral,

  /// The accent: something to press, or the object a screen is about.
  accent,

  /// A status colour — late in red, close in amber. Reserved for rows that
  /// actually are late or close; tinting every icon is the same as tinting
  /// none.
  status,
}

/// The glyph beside a name, and the one way an icon appears next to text.
///
/// **It lost the circle.** Every row used to carry its icon inside a filled,
/// outlined disc, and a screen of twelve rows was twelve discs — the most
/// recognisable ornament of an interface assembled from parts, and one that
/// multiplied the fill colour until it meant nothing. The glyph now stands on
/// its own, in the muted colour, at a fixed width so the names beside it
/// still line up. Colour is left free to say something: red on the one row
/// that is late.
///
/// [AppIconWellSize.xl] keeps a tile, because on an empty or error state the
/// glyph is the whole picture and needs a shape to sit in.
class AppIconWell extends StatelessWidget {
  const AppIconWell({
    super.key,
    required this.icon,
    this.size = AppIconWellSize.m,
    this.tone = AppIconWellTone.neutral,
    this.status,
    this.color,
  });

  final IconData icon;
  final AppIconWellSize size;
  final AppIconWellTone tone;

  /// The status to tint with when [tone] is [AppIconWellTone.status].
  final AppStatus? status;

  /// Overrides the glyph colour.
  final Color? color;

  /// The width every glyph is centred in, so text beside icons of different
  /// shapes starts on one line.
  static double slotWidth(AppIconWellSize size) => switch (size) {
    AppIconWellSize.s => 20,
    AppIconWellSize.m => 24,
    AppIconWellSize.l => 28,
    AppIconWellSize.xl => 64,
  };

  double get _glyph => switch (size) {
    AppIconWellSize.s => 20,
    AppIconWellSize.m => 22,
    AppIconWellSize.l => 26,
    AppIconWellSize.xl => 30,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);

    final visual = tone == AppIconWellTone.status
        ? statusColors(status ?? AppStatus.semPeriodicidade, theme.brightness)
        : null;
    final glyph =
        color ??
        switch (tone) {
          AppIconWellTone.neutral => scheme.onSurfaceVariant,
          AppIconWellTone.accent => scheme.primary,
          AppIconWellTone.status => visual!.foreground,
        };

    if (size != AppIconWellSize.xl) {
      final slot = slotWidth(size);
      return SizedBox(
        width: slot,
        height: slot,
        child: Center(
          child: Icon(icon, size: _glyph, color: glyph),
        ),
      );
    }

    final fill = switch (tone) {
      AppIconWellTone.neutral => tones.iconWell,
      AppIconWellTone.accent => tones.accentSoft,
      AppIconWellTone.status => visual!.background,
    };
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.tile)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: _glyph, color: glyph),
    );
  }
}
