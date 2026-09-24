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

  /// Late or nearly late. The only two states that are allowed to paint a
  /// row, an icon or a line in a status colour.
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

/// One rule for the whole app: red is late, amber is close, the electric blue
/// is fine, and everything else is a quiet blue-grey.
///
/// Red and amber are the only warm tones on a cold interface, which is what
/// makes them register. A green would compete with the accent and give the
/// colour-blind two states that look alike; blue for "fine" keeps late
/// distinct from on track for everyone.
StatusVisual statusColors(AppStatus status, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (status) {
    AppStatus.vencido => StatusVisual(
      foreground: dark ? const Color(0xFFFF6B6B) : const Color(0xFFA32020),
      background: dark ? const Color(0xFF3A1414) : const Color(0xFFFFE3E1),
      icon: Icons.error_outline,
      label: 'Vencido',
    ),
    AppStatus.venceEmBreve => StatusVisual(
      foreground: dark ? const Color(0xFFFFC857) : const Color(0xFF7A4B00),
      background: dark ? const Color(0xFF3A2A0A) : const Color(0xFFFFF0C7),
      icon: Icons.schedule_outlined,
      label: 'Vence em breve',
    ),
    AppStatus.emDia => StatusVisual(
      foreground: dark ? const Color(0xFF4CC2FF) : const Color(0xFF0A5AA8),
      background: dark ? const Color(0xFF0C2E4E) : const Color(0xFFDCEEFF),
      icon: Icons.check_circle_outline,
      label: 'Em dia',
    ),
    AppStatus.semBaseline => StatusVisual(
      foreground: dark ? const Color(0xFFB9C8DA) : const Color(0xFF3B4F66),
      background: dark ? const Color(0xFF1B2A3D) : const Color(0xFFE4EBF3),
      icon: Icons.info_outline,
      label: 'Sem registro',
    ),
    AppStatus.semPeriodicidade => StatusVisual(
      foreground: dark ? const Color(0xFFA9B8CB) : const Color(0xFF46596D),
      background: dark ? const Color(0xFF16273A) : const Color(0xFFE6ECF2),
      icon: Icons.history_outlined,
      label: 'Só histórico',
    ),
    // Only ever seen on the configuration screen: everywhere else an item the
    // vehicle does not have is absent, not greyed out. Muted, and not an alarm
    // colour — nothing is wrong.
    AppStatus.naoSeAplica => StatusVisual(
      foreground: dark ? const Color(0xFFA9B8CB) : const Color(0xFF46596D),
      background: dark ? const Color(0xFF16273A) : const Color(0xFFE6ECF2),
      icon: Icons.remove_circle_outline,
      label: 'Não usa',
    ),
    AppStatus.pago => StatusVisual(
      foreground: dark ? const Color(0xFF4CC2FF) : const Color(0xFF0A5AA8),
      background: dark ? const Color(0xFF0C2E4E) : const Color(0xFFDCEEFF),
      icon: Icons.check_circle_outline,
      label: 'Pago',
    ),
    AppStatus.pendente => StatusVisual(
      foreground: dark ? const Color(0xFFA9B8CB) : const Color(0xFF46596D),
      background: dark ? const Color(0xFF16273A) : const Color(0xFFE6ECF2),
      icon: Icons.event_note_outlined,
      label: 'Pendente',
    ),
    AppStatus.futuro => StatusVisual(
      foreground: dark ? const Color(0xFFB9C6FF) : const Color(0xFF2E3F86),
      background: dark ? const Color(0xFF1E2550) : const Color(0xFFE3E7FF),
      icon: Icons.event_outlined,
      label: 'Futuro',
    ),
    AppStatus.vigente => StatusVisual(
      foreground: dark ? const Color(0xFF4CC2FF) : const Color(0xFF0A5AA8),
      background: dark ? const Color(0xFF0C2E4E) : const Color(0xFFDCEEFF),
      icon: Icons.verified_outlined,
      label: 'Vigente',
    ),
  };
}
