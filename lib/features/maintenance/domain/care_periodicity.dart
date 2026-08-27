import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';

enum CarePeriodicityChoice {
  recommended,
  weekly,
  everyFifteenDays,
  monthly,
  custom,
  dontRemind,
}

/// Maps a human choice onto the PATCH the server already understands.
///
/// Alert windows stay off this path: the server derives them. "Não lembrar"
/// is [PlanUpdate.clearIntervals], not a deactivation — the three intervals
/// become null and the plan keeps grouping history.
PlanUpdate carePeriodicityUpdate({
  required CarePeriodicityChoice choice,
  int? recommendedDays,
  int? customDays,
}) {
  return switch (choice) {
    CarePeriodicityChoice.recommended => PlanUpdate.intervals(
      intervalDays: recommendedDays,
    ),
    CarePeriodicityChoice.weekly => const PlanUpdate.intervals(intervalDays: 7),
    CarePeriodicityChoice.everyFifteenDays => const PlanUpdate.intervals(
      intervalDays: 15,
    ),
    CarePeriodicityChoice.monthly => const PlanUpdate.intervals(
      intervalDays: 30,
    ),
    CarePeriodicityChoice.custom => PlanUpdate.intervals(
      intervalDays: customDays,
    ),
    CarePeriodicityChoice.dontRemind => const PlanUpdate.clearIntervals(),
  };
}

CarePeriodicityChoice carePeriodicityChoiceFor(
  MaintenancePlan plan, {
  int? recommendedDays,
}) {
  if (plan.intervalKm == null &&
      plan.intervalMonths == null &&
      plan.intervalDays == null) {
    return CarePeriodicityChoice.dontRemind;
  }
  if (plan.intervalKm != null || plan.intervalMonths != null) {
    return CarePeriodicityChoice.custom;
  }
  final days = plan.intervalDays;
  if (days == recommendedDays) return CarePeriodicityChoice.recommended;
  return switch (days) {
    7 => CarePeriodicityChoice.weekly,
    15 => CarePeriodicityChoice.everyFifteenDays,
    30 => CarePeriodicityChoice.monthly,
    _ => CarePeriodicityChoice.custom,
  };
}
