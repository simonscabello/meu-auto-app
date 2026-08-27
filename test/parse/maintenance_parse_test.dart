import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';

import '../support/fixtures.dart';
import '../support/parse.dart';

void main() {
  group('MaintenanceItem.fromJson', () {
    final complete = asObjectList(
      loadFixture('maintenance_items_list.json')['data'],
    ).first;
    final nulls = loadFixture('maintenance_item_nulls.json');

    test('parses a complete catalogue item', () {
      final item = MaintenanceItem.fromJson(complete);

      expect(item.slug, 'troca_oleo');
      expect(item.kind, MaintenanceItemKind.maintenance);
      expect(item.defaultIntervalKm, 10000);
      expect(item.defaultIntervalMonths, 12);
      expect(item.defaultIntervalDays, isNull);
      expect(item.isCustom, isFalse);
      expect(item.defaultStrategy, MaintenanceStrategy.periodic);
    });

    test('parses when every optional interval is null', () {
      final item = MaintenanceItem.fromJson(nulls);
      expect(item.defaultIntervalKm, isNull);
      expect(item.defaultIntervalMonths, isNull);
      expect(item.defaultIntervalDays, isNull);
    });

    test('unknown kind falls back without throwing', () {
      final item = MaintenanceItem.fromJson({
        ...complete,
        'kind': 'inspection',
      });
      expect(item.kind, MaintenanceItemKind.desconhecido);
    });

    test('fails clearly when a required field is missing', () {
      expect(
        () => MaintenanceItem.fromJson(withoutKey(complete, 'id')),
        throwsMissingRequired,
      );
      expect(
        () => MaintenanceItem.fromJson(withoutKey(complete, 'name')),
        throwsMissingRequired,
      );
    });
  });

  group('MaintenancePlan.fromJson', () {
    final complete = asObjectList(
      loadFixture('maintenance_plans_list.json')['data'],
    ).first;
    final nulls = loadFixture('maintenance_plan_nulls.json');

    test('parses a complete plan with due fields', () {
      final plan = MaintenancePlan.fromJson(complete);

      expect(plan.status, MaintenanceStatus.emDia);
      expect(plan.origin, MaintenancePlanOrigin.suggested);
      expect(plan.itemKind, MaintenanceItemKind.maintenance);
      expect(plan.intervalKm, 10000);
      expect(plan.dueAtKm, 108200);
      expect(plan.dueOn, const CivilDate(2026, 9, 10));
      expect(plan.lastOccurredOn, const CivilDate(2025, 8, 10));
      expect(plan.strategy, MaintenanceStrategy.periodic);
      expect(plan.historyStatus, MaintenanceHistoryStatus.notAsked);
      expect(plan.historyQuestion, 'Quando foi a última troca de óleo?');
      expect(plan.historyPriority, 100);
    });

    test('parses when every optional is null', () {
      final plan = MaintenancePlan.fromJson(nulls);

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
      expect(plan.strategy, MaintenanceStrategy.noSchedule);
      expect(plan.notes, isNull);
      expect(plan.historyQuestion, isNull);
      expect(plan.historyPriority, 0);
    });

    // A shipped app must survive a server that starts sending a strategy or a
    // history state it has never heard of. Falling back is the easy path here
    // and throwing is impossible, on purpose.
    test('unknown strategy and history status fall back without throwing', () {
      final plan = MaintenancePlan.fromJson({
        ...complete,
        'strategy': 'seasonal',
        'history_status': 'partially_known',
      });

      expect(plan.strategy, MaintenanceStrategy.desconhecido);
      expect(plan.historyStatus, MaintenanceHistoryStatus.desconhecido);
    });

    test('an item the vehicle does not have parses as such', () {
      final plan = MaintenancePlan.fromJson({
        ...complete,
        'status': 'nao_se_aplica',
        'strategy': 'not_applicable',
      });

      expect(plan.status, MaintenanceStatus.naoSeAplica);
      expect(plan.strategy, MaintenanceStrategy.notApplicable);
    });

    test('unknown status, origin and kind fall back without throwing', () {
      final plan = MaintenancePlan.fromJson({
        ...complete,
        'status': 'algo_novo',
        'origin': 'imported',
        'item_kind': 'inspection',
      });

      expect(plan.status, MaintenanceStatus.desconhecido);
      expect(plan.origin, MaintenancePlanOrigin.desconhecido);
      expect(plan.itemKind, MaintenanceItemKind.desconhecido);
    });

    test('fails clearly when a required field is missing', () {
      expect(
        () => MaintenancePlan.fromJson(withoutKey(complete, 'id')),
        throwsMissingRequired,
      );
      expect(
        () => MaintenancePlan.fromJson(withoutKey(complete, 'item_name')),
        throwsMissingRequired,
      );
    });
  });

  group('MaintenancePlanSummary.fromJson', () {
    final summaryJson = loadFixture('maintenance_plan_summary.json');

    test('parses the write response without due fields', () {
      final summary = MaintenancePlanSummary.fromJson(summaryJson);
      expect(summary.intervalKm, 8000);
      expect(summary.intervalDays, isNull);
      expect(summary.origin, MaintenancePlanOrigin.user);
    });

    test('unknown origin falls back without throwing', () {
      final summary = MaintenancePlanSummary.fromJson({
        ...summaryJson,
        'origin': 'imported',
      });
      expect(summary.origin, MaintenancePlanOrigin.desconhecido);
    });

    test('fails clearly when a required field is missing', () {
      expect(
        () => MaintenancePlanSummary.fromJson(withoutKey(summaryJson, 'id')),
        throwsMissingRequired,
      );
    });
  });

  group('MaintenanceRecord.fromJson', () {
    final complete = loadFixture('maintenance_record_get.json');
    final nulls = loadFixture('maintenance_record_nulls.json');

    test('parses a complete record with warranty on the line', () {
      final record = MaintenanceRecord.fromJson(complete);
      final item = record.items.single;

      expect(record.kind, MaintenanceRecordKind.performed);
      expect(record.workshopName, 'Auto Center Silva');
      expect(record.totalCostCents.cents, 42000);
      expect(item.warrantyUntil, const CivilDate(2027, 2, 10));
      expect(item.hasWarranty, isTrue);
    });

    test('parses when every optional is null', () {
      final record = MaintenanceRecord.fromJson(nulls);
      final item = record.items.single;

      expect(record.workshopName, isNull);
      expect(record.notes, isNull);
      expect(item.costCents, isNull);
      expect(item.description, isNull);
      expect(item.partBrand, isNull);
      expect(item.hasWarranty, isFalse);
    });

    test('a care-only record parses with mileage_km null', () {
      final record = MaintenanceRecord.fromJson({
        ...complete,
        'mileage_km': null,
      });
      expect(record.mileageKm, isNull);
    });

    test('unknown kind falls back without throwing', () {
      final record = MaintenanceRecord.fromJson({
        ...complete,
        'kind': 'estimated',
      });
      expect(record.kind, MaintenanceRecordKind.desconhecido);
    });

    test('fails clearly when a required field is missing', () {
      expect(
        () => MaintenanceRecord.fromJson(withoutKey(complete, 'id')),
        throwsMissingRequired,
      );
      expect(
        () => MaintenanceRecord.fromJson(withoutKey(complete, 'occurred_on')),
        throwsMissingRequired,
      );
      expect(
        () => MaintenanceRecord.fromJson(
          withoutKey(complete, 'total_cost_cents'),
        ),
        throwsMissingRequired,
      );
    });
  });
}
