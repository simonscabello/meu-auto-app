import 'formatters.dart';

/// Presentation copy only. Remaining km/days come from the API; this file
/// never computes a due date, an interval or a warranty.

const _phraseDaysLimit = 45;

String? remainingKmPhrase(int? remainingKm) {
  if (remainingKm == null) return null;
  if (remainingKm > 0) return 'faltam ${formatKm(remainingKm)}';
  if (remainingKm == 0) return 'vence agora';
  return 'passou ${formatKm(-remainingKm)}';
}

String? remainingDaysPhrase(int? remainingDays) {
  if (remainingDays == null) return null;
  if (remainingDays == 0) return 'vence hoje';
  if (remainingDays == 1) return 'vence amanhã';
  if (remainingDays == -1) return 'venceu ontem';

  final distance = remainingDays.abs();
  if (distance <= _phraseDaysLimit) {
    if (remainingDays > 0) return 'faltam $distance dias';
    return 'venceu há $distance dias';
  }

  final months = _approximateMonths(distance);
  final unit = months == 1 ? 'mês' : 'meses';
  if (remainingDays > 0) return 'faltam cerca de $months $unit';
  return 'venceu há cerca de $months $unit';
}

/// Joins the two remaining dimensions, leading with the closer one.
///
/// "Closer" is the smaller remaining number (more negative first). That is
/// a display choice, not a conversion of km into days.
String? dueSummary({int? remainingKm, int? remainingDays}) {
  final km = remainingKmPhrase(remainingKm);
  final days = remainingDaysPhrase(remainingDays);
  if (km == null) return days;
  if (days == null) return km;
  if (remainingDays! <= remainingKm!) return '$days · $km';
  return '$km · $days';
}

String maintenanceStatusPhrase(
  String status, {
  int? remainingKm,
  int? remainingDays,
}) {
  switch (status) {
    case 'vencido':
      return 'Está vencida';
    case 'vence_em_breve':
      return dueSummary(
            remainingKm: remainingKm,
            remainingDays: remainingDays,
          ) ??
          '';
    case 'em_dia':
      return 'Em dia';
    case 'sem_baseline':
      return 'Informe a última vez para começarmos a contar';
    case 'sem_periodicidade':
      return 'Só histórico, não vence';
    default:
      return '';
  }
}

String? paidLatePhrase(int remainingDays) {
  if (remainingDays >= 0) return null;
  final days = remainingDays.abs();
  final unit = days == 1 ? 'dia' : 'dias';
  return 'pago com $days $unit de atraso';
}

/// Turns a day count the server already computed into a coarse month
/// figure for copy. Not calendar arithmetic.
int _approximateMonths(int days) {
  final months = (days + 15) ~/ 30;
  if (months < 1) return 1;
  return months;
}
