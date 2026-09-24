import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/plan_progress.dart';

/// The bar beside "faltam 4.112 km" is drawn only from figures the server
/// sent. These pin the two ways a fraction is formed, and the cases where
/// there must be no bar at all.
void main() {
  test('distance: what has been run over the interval', () {
    final plan = _plan(intervalKm: 10000, remainingKm: 4000);
    expect(planProgress(plan), closeTo(0.6, 0.0001));
  });

  test('time: what has elapsed between the last service and the due date', () {
    final plan = _plan(
      lastOccurredOn: const CivilDate(2026, 1, 1),
      dueOn: const CivilDate(2027, 1, 1),
      remainingDays: 73,
    );
    // 365 days between the two; 73 remain.
    expect(planProgress(plan), closeTo(1 - 73 / 365, 0.0001));
  });

  test('a care item falls back to its interval in days', () {
    final plan = _plan(intervalDays: 15, remainingDays: 3);
    expect(planProgress(plan), closeTo(0.8, 0.0001));
  });

  test('the closer dimension wins', () {
    final plan = _plan(
      intervalKm: 10000,
      remainingKm: 9000,
      lastOccurredOn: const CivilDate(2026, 1, 1),
      dueOn: const CivilDate(2026, 12, 31),
      remainingDays: 30,
    );
    expect(planProgress(plan), greaterThan(0.9));
  });

  test('late is full, and never past full', () {
    expect(
      planProgress(
        _plan(
          status: MaintenanceStatus.vencido,
          intervalKm: 10000,
          remainingKm: -1200,
        ),
      ),
      1,
    );
    expect(planProgress(_plan(intervalKm: 10000, remainingKm: -500)), 1);
  });

  test('nothing to measure from means no bar', () {
    expect(planProgress(_plan(status: MaintenanceStatus.semBaseline)), isNull);
    expect(
      planProgress(_plan(status: MaintenanceStatus.semPeriodicidade)),
      isNull,
    );
    expect(planProgress(_plan()), isNull);
    // Months alone are not turned into days: that would be a guess.
    expect(planProgress(_plan(intervalMonths: 12, remainingDays: 100)), isNull);
  });

  test('planProgressById leaves out what has no bar', () {
    final byId = planProgressById([
      _plan(id: 'a', intervalKm: 10000, remainingKm: 2500),
      _plan(id: 'b', status: MaintenanceStatus.semBaseline),
    ]);
    expect(byId.keys, ['a']);
    expect(byId['a'], closeTo(0.75, 0.0001));
  });
}

MaintenancePlan _plan({
  String id = 'p1',
  MaintenanceStatus status = MaintenanceStatus.emDia,
  int? intervalKm,
  int? intervalMonths,
  int? intervalDays,
  int? remainingKm,
  int? remainingDays,
  CivilDate? lastOccurredOn,
  CivilDate? dueOn,
}) {
  return MaintenancePlan(
    id: id,
    maintenanceItemId: 'i1',
    itemSlug: 'troca_oleo',
    itemName: 'Troca de óleo do motor',
    itemKind: intervalDays != null
        ? MaintenanceItemKind.care
        : MaintenanceItemKind.maintenance,
    intervalKm: intervalKm,
    intervalMonths: intervalMonths,
    intervalDays: intervalDays,
    alertKm: 1000,
    alertDays: 15,
    origin: MaintenancePlanOrigin.suggested,
    strategy: MaintenanceStrategy.periodic,
    historyStatus: MaintenanceHistoryStatus.notAsked,
    status: status,
    remainingKm: remainingKm,
    remainingDays: remainingDays,
    lastOccurredOn: lastOccurredOn,
    dueOn: dueOn,
  );
}
