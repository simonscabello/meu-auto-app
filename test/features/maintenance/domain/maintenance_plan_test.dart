import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';

void main() {
  group('MaintenancePlan.fromJson', () {
    test('a plan measured only in kilometres', () {
      final plan = MaintenancePlan.fromJson(_planJson(kmOnly));

      expect(plan.intervalKm, 10000);
      expect(plan.intervalMonths, isNull);
      expect(plan.intervalDays, isNull);
      expect(plan.dueAtKm, 108200);
      expect(plan.dueOn, isNull);
      expect(plan.remainingKm, 1550);
      expect(plan.remainingDays, isNull);
      expect(plan.status, MaintenanceStatus.emDia);
      expect(plan.itemKind, MaintenanceItemKind.maintenance);
    });

    test('a plan measured only in months', () {
      final plan = MaintenancePlan.fromJson(_planJson(monthsOnly));

      expect(plan.intervalKm, isNull);
      expect(plan.intervalMonths, 12);
      expect(plan.intervalDays, isNull);
      expect(plan.dueAtKm, isNull);
      expect(plan.dueOn, const CivilDate(2027, 8, 10));
      expect(plan.remainingKm, isNull);
      expect(plan.remainingDays, 349);
    });

    test('a plan measured only in days', () {
      final plan = MaintenancePlan.fromJson(_planJson(daysOnly));

      expect(plan.intervalKm, isNull);
      expect(plan.intervalMonths, isNull);
      expect(plan.intervalDays, 15);
      expect(plan.dueAtKm, isNull);
      expect(plan.dueOn, const CivilDate(2026, 9, 3));
      expect(plan.remainingKm, isNull);
      expect(plan.remainingDays, 8);
      expect(plan.itemKind, MaintenanceItemKind.care);
    });

    test('a plan with no interval at all', () {
      final plan = MaintenancePlan.fromJson(_planJson(none));

      expect(plan.intervalKm, isNull);
      expect(plan.intervalMonths, isNull);
      expect(plan.intervalDays, isNull);
      expect(plan.dueAtKm, isNull);
      expect(plan.dueOn, isNull);
      expect(plan.remainingKm, isNull);
      expect(plan.remainingDays, isNull);
      expect(plan.lastOccurredOn, isNull);
      expect(plan.lastMileageKm, isNull);
      expect(plan.status, MaintenanceStatus.semPeriodicidade);
    });

    test('unknown status and origin fall back instead of throwing', () {
      final plan = MaintenancePlan.fromJson(
        _planJson({
          ...kmOnly,
          'status': 'algo_novo',
          'origin': 'imported',
          'item_kind': 'inspection',
        }),
      );

      expect(plan.status, MaintenanceStatus.desconhecido);
      expect(plan.origin, MaintenancePlanOrigin.desconhecido);
      expect(plan.itemKind, MaintenanceItemKind.desconhecido);
      expect(plan.status.wire, isEmpty);
    });
  });

  test('a summary parses the write response without due fields', () {
    final summary = MaintenancePlanSummary.fromJson({
      'id': _id,
      'maintenance_item_id': _itemId,
      'interval_km': 8000,
      'interval_months': 12,
      'interval_days': null,
      'alert_km': 800,
      'alert_days': 15,
      'origin': 'user',
    });

    expect(summary.intervalKm, 8000);
    expect(summary.intervalMonths, 12);
    expect(summary.intervalDays, isNull);
    expect(summary.origin, MaintenancePlanOrigin.user);
  });
}

Map<String, dynamic> _planJson(Map<String, dynamic> fields) {
  return {
    'id': _id,
    'maintenance_item_id': _itemId,
    'item_slug': 'troca_oleo',
    'item_name': 'Troca de óleo do motor',
    'item_kind': 'maintenance',
    'alert_km': 1000,
    'alert_days': 15,
    'origin': 'suggested',
    'status': 'em_dia',
    ...fields,
  };
}

const _id = 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa';
const _itemId = 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb';

const kmOnly = {
  'interval_km': 10000,
  'interval_months': null,
  'interval_days': null,
  'due_at_km': 108200,
  'due_on': null,
  'remaining_km': 1550,
  'remaining_days': null,
  'last_occurred_on': '2025-08-10',
  'last_mileage_km': 98200,
};

const monthsOnly = {
  'item_slug': 'extintor',
  'item_name': 'Extintor',
  'interval_km': null,
  'interval_months': 12,
  'interval_days': null,
  'due_at_km': null,
  'due_on': '2027-08-10',
  'remaining_km': null,
  'remaining_days': 349,
};

const daysOnly = {
  'item_slug': 'calibrar_pneus',
  'item_name': 'Calibrar os pneus',
  'item_kind': 'care',
  'interval_km': null,
  'interval_months': null,
  'interval_days': 15,
  'due_at_km': null,
  'due_on': '2026-09-03',
  'remaining_km': null,
  'remaining_days': 8,
  'status': 'vence_em_breve',
};

const none = {
  'interval_km': null,
  'interval_months': null,
  'interval_days': null,
  'due_at_km': null,
  'due_on': null,
  'remaining_km': null,
  'remaining_days': null,
  'last_occurred_on': null,
  'last_mileage_km': null,
  'status': 'sem_periodicidade',
};
