import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';

/// How far along its interval a plan is, as a fraction from 0 to 1 — or null
/// when the figures to say so honestly are not there.
///
/// Nothing here is derived from the clock. Every input arrived computed by
/// the server: the interval, what remains of it, the last service and the
/// due date. The bar this feeds is decoration beside a sentence that says the
/// same thing in words, so when the sentence cannot be turned into a fraction
/// there is no bar rather than a guessed one.
///
/// Two dimensions can each yield a fraction, and the larger wins because the
/// closer one is what will come due first:
///
///  * distance — `1 - remaining_km / interval_km`;
///  * time — `1 - remaining_days / (due_on - last_occurred_on)`, both dates
///    from the server, or `interval_days` for a care item.
///
/// A plan already late is full. A plan with no baseline has nothing to
/// measure from and yields null.
double? planProgress(MaintenancePlan plan) {
  if (plan.status == MaintenanceStatus.semBaseline ||
      plan.status == MaintenanceStatus.semPeriodicidade ||
      plan.status == MaintenanceStatus.naoSeAplica) {
    return null;
  }
  if (plan.status == MaintenanceStatus.vencido) {
    return 1;
  }

  double? best;

  final intervalKm = plan.intervalKm;
  final remainingKm = plan.remainingKm;
  if (intervalKm != null && intervalKm > 0 && remainingKm != null) {
    best = _keepLarger(best, 1 - remainingKm / intervalKm);
  }

  final remainingDays = plan.remainingDays;
  if (remainingDays != null) {
    final dueOn = plan.dueOn;
    final last = plan.lastOccurredOn;
    if (dueOn != null && last != null) {
      final total = last.daysUntil(dueOn);
      if (total > 0) {
        best = _keepLarger(best, 1 - remainingDays / total);
      }
    } else {
      final intervalDays = plan.intervalDays;
      if (intervalDays != null && intervalDays > 0) {
        best = _keepLarger(best, 1 - remainingDays / intervalDays);
      }
    }
  }

  if (best == null) return null;
  return best.clamp(0.0, 1.0);
}

double _keepLarger(double? current, double candidate) {
  if (current == null) return candidate;
  return candidate > current ? candidate : current;
}

/// The fractions for every plan in a list, keyed by plan id, leaving out the
/// ones that have none. What Início looks up when it draws an upcoming item.
Map<String, double> planProgressById(Iterable<MaintenancePlan> plans) {
  final byId = <String, double>{};
  for (final plan in plans) {
    final fraction = planProgress(plan);
    if (fraction != null) byId[plan.id] = fraction;
  }
  return byId;
}
