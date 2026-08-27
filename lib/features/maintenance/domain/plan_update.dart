import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';

/// PATCH body for a maintenance plan.
///
/// Each constructor is one intent, and they do not mix on purpose. `clear_*` has
/// to travel alone: the server refuses it next to the field it clears, because
/// `null` already means "leave this one unchanged".
final class PlanUpdate {
  const PlanUpdate.intervals({
    this.intervalKm,
    this.intervalMonths,
    this.intervalDays,
    this.alertKm,
    this.alertDays,
  }) : clearIntervals = false,
       clearNotes = false,
       strategy = null,
       historyStatus = null,
       notes = null;

  const PlanUpdate.clearIntervals()
    : clearIntervals = true,
      clearNotes = false,
      intervalKm = null,
      intervalMonths = null,
      intervalDays = null,
      alertKm = null,
      alertDays = null,
      strategy = null,
      historyStatus = null,
      notes = null;

  /// "Meu carro não tem isso" — and its undo.
  ///
  /// The note travels with it because the two are one thought: the owner is
  /// saying what their car is, and may want to write down why.
  const PlanUpdate.applicability({required this.strategy, this.notes})
    : clearIntervals = false,
      clearNotes = false,
      intervalKm = null,
      intervalMonths = null,
      intervalDays = null,
      alertKm = null,
      alertDays = null,
      historyStatus = null;

  /// "Não sei" or "nunca foi feito" about the past.
  ///
  /// Deliberately NOT a maintenance record: a record asserts a date and a
  /// mileage, and somebody who does not remember has neither. Writing one anyway
  /// would put a fabricated fact into a history whose whole value is being
  /// trustworthy.
  const PlanUpdate.history(this.historyStatus)
    : clearIntervals = false,
      clearNotes = false,
      intervalKm = null,
      intervalMonths = null,
      intervalDays = null,
      alertKm = null,
      alertDays = null,
      strategy = null,
      notes = null;

  const PlanUpdate.clearNotes()
    : clearIntervals = false,
      clearNotes = true,
      intervalKm = null,
      intervalMonths = null,
      intervalDays = null,
      alertKm = null,
      alertDays = null,
      strategy = null,
      historyStatus = null,
      notes = null;

  final bool clearIntervals;
  final bool clearNotes;
  final int? intervalKm;
  final int? intervalMonths;
  final int? intervalDays;
  final int? alertKm;
  final int? alertDays;
  final MaintenanceStrategy? strategy;
  final MaintenanceHistoryStatus? historyStatus;
  final String? notes;

  Map<String, dynamic> toJson() {
    if (clearIntervals) {
      return const {'clear_intervals': true};
    }
    if (clearNotes) {
      return const {'clear_notes': true};
    }
    return {
      'interval_km': ?intervalKm,
      'interval_months': ?intervalMonths,
      'interval_days': ?intervalDays,
      'alert_km': ?alertKm,
      'alert_days': ?alertDays,
      'strategy': ?strategy?.wire,
      'history_status': ?historyStatus?.wire,
      'notes': ?notes,
    };
  }
}
