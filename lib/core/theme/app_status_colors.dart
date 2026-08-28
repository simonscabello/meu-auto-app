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

///
/// Overdue is rust/orange, due-soon is amber, on-track is teal — not red
/// versus green. [AppStatus.semBaseline] is an informational slate: pending
/// configuration, not an alert.
StatusVisual statusColors(AppStatus status, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (status) {
    AppStatus.vencido => StatusVisual(
      foreground: dark ? const Color(0xFFFECBA1) : const Color(0xFF9A3412),
      background: dark ? const Color(0xFF3B1A0A) : const Color(0xFFFFF1E6),
      icon: Icons.error,
      label: 'Vencido',
    ),
    AppStatus.venceEmBreve => StatusVisual(
      foreground: dark ? const Color(0xFFFDE68A) : const Color(0xFF854D0E),
      background: dark ? const Color(0xFF3D2A08) : const Color(0xFFFEF6DC),
      icon: Icons.schedule,
      label: 'Vence em breve',
    ),
    AppStatus.emDia => StatusVisual(
      foreground: dark ? const Color(0xFF99F6E4) : const Color(0xFF115E59),
      background: dark ? const Color(0xFF0A2F2C) : const Color(0xFFE6F4F2),
      icon: Icons.check_circle,
      label: 'Em dia',
    ),
    AppStatus.semBaseline => StatusVisual(
      foreground: dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
      background: dark ? const Color(0xFF1E293B) : const Color(0xFFE8EEF4),
      icon: Icons.info,
      label: 'Sem registro',
    ),
    AppStatus.semPeriodicidade => StatusVisual(
      foreground: dark ? const Color(0xFFC5D0D0) : const Color(0xFF3F4C4E),
      background: dark ? const Color(0xFF252A2A) : const Color(0xFFEEF0F1),
      icon: Icons.history,
      label: 'Só histórico',
    ),
    // Only ever seen on the configuration screen: everywhere else an item the
    // vehicle does not have is absent, not greyed out. Muted, and not an alarm
    // colour — nothing is wrong.
    AppStatus.naoSeAplica => StatusVisual(
      foreground: dark ? const Color(0xFFC5D0D0) : const Color(0xFF3F4C4E),
      background: dark ? const Color(0xFF252A2A) : const Color(0xFFEEF0F1),
      icon: Icons.remove_circle,
      label: 'Não usa',
    ),
    AppStatus.pago => StatusVisual(
      foreground: dark ? const Color(0xFF99F6E4) : const Color(0xFF115E59),
      background: dark ? const Color(0xFF0A2F2C) : const Color(0xFFE6F4F2),
      icon: Icons.check_circle,
      label: 'Pago',
    ),
    AppStatus.pendente => StatusVisual(
      foreground: dark ? const Color(0xFFC5D0D0) : const Color(0xFF3F4C4E),
      background: dark ? const Color(0xFF252A2A) : const Color(0xFFEEF0F1),
      icon: Icons.event_note,
      label: 'Pendente',
    ),
    AppStatus.futuro => StatusVisual(
      foreground: dark ? const Color(0xFFC7D2FE) : const Color(0xFF1E3A5F),
      background: dark ? const Color(0xFF1E1B4B) : const Color(0xFFE8EEF8),
      icon: Icons.event,
      label: 'Futuro',
    ),
    AppStatus.vigente => StatusVisual(
      foreground: dark ? const Color(0xFF99F6E4) : const Color(0xFF115E59),
      background: dark ? const Color(0xFF0A2F2C) : const Color(0xFFE6F4F2),
      icon: Icons.verified,
      label: 'Vigente',
    ),
  };
}
