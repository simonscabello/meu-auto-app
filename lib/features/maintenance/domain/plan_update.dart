/// PATCH body for a maintenance plan.
///
/// `clear_intervals` has to travel alone: the server refuses it next to any
/// interval field, because `null` already means "leave this one unchanged".
final class PlanUpdate {
  const PlanUpdate.intervals({
    this.intervalKm,
    this.intervalMonths,
    this.intervalDays,
    this.alertKm,
    this.alertDays,
  }) : clearIntervals = false;

  const PlanUpdate.clearIntervals()
    : clearIntervals = true,
      intervalKm = null,
      intervalMonths = null,
      intervalDays = null,
      alertKm = null,
      alertDays = null;

  final bool clearIntervals;
  final int? intervalKm;
  final int? intervalMonths;
  final int? intervalDays;
  final int? alertKm;
  final int? alertDays;

  Map<String, dynamic> toJson() {
    if (clearIntervals) {
      return const {'clear_intervals': true};
    }
    return {
      'interval_km': ?intervalKm,
      'interval_months': ?intervalMonths,
      'interval_days': ?intervalDays,
      'alert_km': ?alertKm,
      'alert_days': ?alertDays,
    };
  }
}
