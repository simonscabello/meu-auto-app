import 'package:flutter/material.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

enum AppIconWellSize {
  /// Beside a settings row.
  s,

  /// Beside a list row. The default.
  m,

  /// On a card or a tile.
  l,

  /// The one icon on an empty or error state.
  xl,
}

/// How the well is tinted.
enum AppIconWellTone {
  /// A neutral fill and a muted icon. What most rows carry.
  neutral,

  /// The accent, for the icon of something selected, fine, or brand-level.
  accent,

  /// A status tint — late in red, close in amber. Reserved for rows that
  /// are actually late or close; tinting every well is the same as tinting
  /// none.
  status,
}

/// An icon in a circle.
///
/// The one way an icon appears beside a name anywhere in the app: a 1px
/// edge, a fill one step off the surface, and the glyph centred. Rows,
/// cards, empty states and the quick actions all use it, which is what makes
/// them read as one family at a glance.
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

  /// Overrides the icon colour alone. For a tinted icon on a neutral well.
  final Color? color;

  double get _diameter => switch (size) {
    AppIconWellSize.s => 32,
    AppIconWellSize.m => 38,
    AppIconWellSize.l => 46,
    AppIconWellSize.xl => 64,
  };

  double get _glyph => switch (size) {
    AppIconWellSize.s => 16,
    AppIconWellSize.m => 19,
    AppIconWellSize.l => 22,
    AppIconWellSize.xl => 30,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);

    Color fill;
    Color edge;
    Color glyph;
    switch (tone) {
      case AppIconWellTone.neutral:
        fill = tones.iconWell;
        edge = tones.stroke;
        glyph = color ?? scheme.onSurfaceVariant;
      case AppIconWellTone.accent:
        fill = tones.accentSoft;
        edge = scheme.primary.withValues(alpha: 0.35);
        glyph = color ?? scheme.primary;
      case AppIconWellTone.status:
        final visual = statusColors(
          status ?? AppStatus.semPeriodicidade,
          theme.brightness,
        );
        fill = visual.background;
        edge = visual.foreground.withValues(alpha: 0.35);
        glyph = color ?? visual.foreground;
    }

    return Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: edge),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: _glyph, color: glyph),
    );
  }
}
