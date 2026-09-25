import 'civil_date.dart';
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
  // Past two years, months stop meaning anything: "há cerca de 58 meses" makes
  // the owner divide by twelve.
  if (months >= 24) {
    final years = months ~/ 12;
    if (remainingDays > 0) return 'faltam mais de $years anos';
    return 'venceu há mais de $years anos';
  }
  final unit = months == 1 ? 'mês' : 'meses';
  if (remainingDays > 0) return 'faltam cerca de $months $unit';
  return 'venceu há cerca de $months $unit';
}

/// A deadline in days, as the sentence a row carries: "Venceu há 13 dias",
/// "Venceu ontem", "Vence hoje", "Vence amanhã", "Vence em 21 dias",
/// "Vence em cerca de 3 meses".
///
/// One wording for every deadline in the app — a care habit, an IPVA, a
/// policy — so the same fact reads the same on Início and on its own tab.
/// The count comes from the server.
String dueInDaysPhrase(int remainingDays) {
  if (remainingDays > 1 && remainingDays <= _phraseDaysLimit) {
    return 'Vence em $remainingDays dias';
  }
  if (remainingDays > _phraseDaysLimit) {
    final months = _approximateMonths(remainingDays);
    if (months >= 24) return 'Vence em cerca de ${months ~/ 12} anos';
    return months == 1
        ? 'Vence em cerca de 1 mês'
        : 'Vence em cerca de $months meses';
  }
  return capitalizeFirst(remainingDaysPhrase(remainingDays)!);
}

/// The sentence with its first letter up: phrases here are written to be
/// joined into a line, and some of them start one.
String capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

/// How late or how close, in the one dimension that decides: "Venceu há 13
/// dias", "Vence em 21 dias", "Passou 1.200 km", "Faltam 800 km".
///
/// The closer dimension leads, the way [dueSummary] orders them, and only it
/// is said: a row is read at a glance, and "venceu há 13 dias · passou 1.200
/// km" asks the owner to weigh two facts when one decides. Figures come from
/// the server; nothing here is date arithmetic.
String? urgencyPhrase({int? remainingKm, int? remainingDays}) {
  final days = remainingDays;
  final km = remainingKm;
  if (days == null && km == null) return null;
  if (km == null) return dueInDaysPhrase(days!);
  if (days == null) return capitalizeFirst(remainingKmPhrase(km)!);
  // Both dimensions arrived. A day and a kilometre cannot be compared, so the
  // one that is actually late — or, if neither is, the one that is close —
  // leads, and the other follows only when it is late too.
  final daysLate = days < 0;
  final kmLate = km < 0;
  if (daysLate && kmLate) {
    return '${dueInDaysPhrase(days)}$dotSep${remainingKmPhrase(km)}';
  }
  if (kmLate) return capitalizeFirst(remainingKmPhrase(km)!);
  if (daysLate) return dueInDaysPhrase(days);
  return 'Faltam ${formatKm(km)} ou ${days == 1 ? '1 dia' : '$days dias'}';
}

/// Upcoming, as the distance to it: "Faltam 4.200 km ou 30 dias",
/// "Faltam 4.200 km ou 12/02/2027", "Vence em 12/02/2027".
///
/// The date is written as a date once it is more than about a month and a
/// half out, because "faltam 197 dias" makes the owner do arithmetic the
/// calendar already did.
String? upcomingSummary({
  int? remainingKm,
  int? remainingDays,
  CivilDate? dueOn,
}) {
  final km = remainingKm != null && remainingKm > 0
      ? formatKm(remainingKm)
      : null;

  String? when;
  var whenIsDate = false;
  if (remainingDays != null && remainingDays >= 0) {
    if (remainingDays == 0) {
      return 'Vence hoje';
    }
    if (remainingDays > _phraseDaysLimit && dueOn != null) {
      when = formatCivilDate(dueOn);
      whenIsDate = true;
    } else {
      when = remainingDays == 1 ? '1 dia' : '$remainingDays dias';
    }
  }

  if (km == null && when == null) return null;
  if (km != null && when != null) {
    return whenIsDate ? 'Faltam $km ou até $when' : 'Faltam $km ou $when';
  }
  if (km != null) return 'Faltam $km';
  return whenIsDate ? 'Vence em $when' : 'Faltam $when';
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
  if (remainingDays! <= remainingKm!) return '$days$dotSep$km';
  return '$km$dotSep$days';
}

String maintenanceStatusPhrase(
  String status, {
  int? remainingKm,
  int? remainingDays,
}) {
  switch (status) {
    case 'vencido':
      // By how much, when the server said. "Está vencida" was feminine for
      // "Filtro de óleo" too, and said nothing the row's colour had not.
      return urgencyPhrase(
            remainingKm: remainingKm,
            remainingDays: remainingDays,
          ) ??
          'Vencido';
    case 'vence_em_breve':
      return urgencyPhrase(
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
    case 'nao_se_aplica':
      // Plain, and about the car rather than about the model. Nobody needs to
      // hear the word "aplicabilidade" to understand this.
      return 'Seu carro não usa';
    default:
      return '';
  }
}

/// How late a payment was, from how many days after the due date it was paid.
///
/// It used to take `remaining_days`, which the server counts from TODAY to the
/// due date: an IPVA paid on the day it fell due read "pago com 60 dias de
/// atraso" two months later, and more every day after. Lateness is the gap
/// between two dates that do not move — the due date and the payment date.
String? paidLatePhrase(int daysLate) {
  if (daysLate <= 0) return null;
  final unit = daysLate == 1 ? 'dia' : 'dias';
  return 'pago com $daysLate $unit de atraso';
}

/// Turns a day count the server already computed into a coarse month
/// figure for copy. Not calendar arithmetic.
int _approximateMonths(int days) {
  final months = (days + 15) ~/ 30;
  if (months < 1) return 1;
  return months;
}
