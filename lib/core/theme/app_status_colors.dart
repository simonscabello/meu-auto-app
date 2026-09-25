import 'package:flutter/material.dart';

/// Visual vocabulary for every status the API can return.
///
/// This is not a domain model. Feature enums map onto these values so that
/// colour, icon and label are decided in one place.
enum AppStatus {
  vencido,
  venceEmBreve,
  emDia,
  semBaseline,
  semPeriodicidade,
  naoSeAplica,
  pago,
  pendente,
  futuro,
  vigente;

  /// Unknown values fall through to [semPeriodicidade]: neutral, not a
  /// problem. Never throws.
  static AppStatus fromWire(String value) {
    return switch (value) {
      'vencido' => AppStatus.vencido,
      'vence_em_breve' => AppStatus.venceEmBreve,
      'em_dia' => AppStatus.emDia,
      'sem_baseline' => AppStatus.semBaseline,
      'sem_periodicidade' => AppStatus.semPeriodicidade,
      'nao_se_aplica' => AppStatus.naoSeAplica,
      'pago' => AppStatus.pago,
      'pendente' => AppStatus.pendente,
      'futuro' => AppStatus.futuro,
      'vigente' => AppStatus.vigente,
      _ => AppStatus.semPeriodicidade,
    };
  }

  /// Late or nearly late. The only two states that are allowed to paint an
  /// icon or a line in a warm colour.
  bool get isLoud => this == vencido || this == venceEmBreve;
}

/// Foreground + background plus the icon and label that make the pair
/// accessible without relying on colour alone.
final class StatusVisual {
  const StatusVisual({
    required this.foreground,
    required this.background,
    required this.icon,
    required this.label,
  });

  final Color foreground;
  final Color background;
  final IconData icon;
  final String label;
}

/// One rule for the whole app: **red is late, amber is close, green is done,
/// blue is on track, and everything else is quiet grey.**
///
/// Red and amber are the only warm tones on a cool interface, which is what
/// makes them register at a glance — and why neither is ever used to
/// decorate. Green is "done" (a paid tax), not "fine": on-track states stay in
/// the accent blue, so a screen full of healthy items is calm rather than a
/// field of green lights. Every status also carries its own glyph and word,
/// so no two states are told apart by colour alone.
StatusVisual statusColors(AppStatus status, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  const quietDark = Color(0xFFB7C0CC);
  const quietDarkBg = Color(0xFF232A34);
  const quietLight = Color(0xFF45505E);
  const quietLightBg = Color(0xFFE8ECF1);
  const onTrackDark = Color(0xFF5B9DFF);
  const onTrackDarkBg = Color(0xFF16283E);
  const onTrackLight = Color(0xFF1558C0);
  const onTrackLightBg = Color(0xFFDCE8FD);

  return switch (status) {
    AppStatus.vencido => StatusVisual(
      foreground: dark ? const Color(0xFFF07070) : const Color(0xFFB42A28),
      background: dark ? const Color(0xFF3A1719) : const Color(0xFFFCE4E3),
      icon: Icons.error_outline,
      label: 'Vencido',
    ),
    AppStatus.venceEmBreve => StatusVisual(
      foreground: dark ? const Color(0xFFEFB54A) : const Color(0xFF8A5207),
      background: dark ? const Color(0xFF33270F) : const Color(0xFFFCEFD6),
      icon: Icons.schedule_outlined,
      label: 'Vence em breve',
    ),
    AppStatus.emDia => StatusVisual(
      foreground: dark ? onTrackDark : onTrackLight,
      background: dark ? onTrackDarkBg : onTrackLightBg,
      icon: Icons.check_circle_outline,
      label: 'Em dia',
    ),
    AppStatus.semBaseline => StatusVisual(
      foreground: dark ? quietDark : quietLight,
      background: dark ? quietDarkBg : quietLightBg,
      icon: Icons.help_outline,
      label: 'Sem registro',
    ),
    AppStatus.semPeriodicidade => StatusVisual(
      foreground: dark ? quietDark : quietLight,
      background: dark ? quietDarkBg : quietLightBg,
      icon: Icons.history_outlined,
      label: 'Só histórico',
    ),
    // Only ever seen on the configuration screen: everywhere else an item the
    // vehicle does not have is absent, not greyed out. Quiet — nothing is
    // wrong.
    AppStatus.naoSeAplica => StatusVisual(
      foreground: dark ? quietDark : quietLight,
      background: dark ? quietDarkBg : quietLightBg,
      icon: Icons.remove_circle_outline,
      label: 'Não usa',
    ),
    AppStatus.pago => StatusVisual(
      foreground: dark ? const Color(0xFF57C38D) : const Color(0xFF1D7A4A),
      background: dark ? const Color(0xFF12301F) : const Color(0xFFDDF3E6),
      icon: Icons.check_circle_outline,
      label: 'Pago',
    ),
    AppStatus.pendente => StatusVisual(
      foreground: dark ? quietDark : quietLight,
      background: dark ? quietDarkBg : quietLightBg,
      icon: Icons.event_note_outlined,
      label: 'Pendente',
    ),
    AppStatus.futuro => StatusVisual(
      foreground: dark ? quietDark : quietLight,
      background: dark ? quietDarkBg : quietLightBg,
      icon: Icons.event_outlined,
      label: 'Futuro',
    ),
    AppStatus.vigente => StatusVisual(
      foreground: dark ? onTrackDark : onTrackLight,
      background: dark ? onTrackDarkBg : onTrackLightBg,
      icon: Icons.verified_outlined,
      label: 'Vigente',
    ),
  };
}
