import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/onboarding/domain/calibrar_questions.dart';

void main() {
  group('selectCalibrarPlans', () {
    test('orders by the priority the server sent, capped at five', () {
      final selected = selectCalibrarPlans([
        _plan('palhetas', priority: 25),
        _plan('alinhamento', priority: 30),
        _plan('filtro_ar', priority: 50),
        _plan('fluido_freio', priority: 60),
        _plan('bateria', priority: 70, status: MaintenanceStatus.emDia),
        _plan('pneus', priority: 85),
        _plan('revisao', priority: 95, status: MaintenanceStatus.vencido),
        _plan('troca_oleo', priority: 100),
        _plan('velas', priority: 55),
      ]);

      expect(
        [for (final plan in selected) plan.itemSlug],
        ['troca_oleo', 'pneus', 'fluido_freio', 'velas', 'filtro_ar'],
      );
    });

    test('returns fewer than five when that is all that is missing', () {
      final selected = selectCalibrarPlans([
        _plan('revisao', priority: 95),
        _plan('troca_oleo', priority: 100, status: MaintenanceStatus.emDia),
      ]);

      expect([for (final plan in selected) plan.itemSlug], ['revisao']);
    });

    // The behaviour that makes "não sei" worth storing. Answering once has to
    // end the question; the old flow asked the same thing on every visit.
    test('never asks again about something already answered', () {
      final selected = selectCalibrarPlans([
        _plan(
          'troca_oleo',
          priority: 100,
          historyStatus: MaintenanceHistoryStatus.unknown,
        ),
        _plan(
          'velas',
          priority: 55,
          historyStatus: MaintenanceHistoryStatus.never,
        ),
        _plan('pneus', priority: 85),
      ]);

      expect([for (final plan in selected) plan.itemSlug], ['pneus']);
    });

    // Nothing here invents wording. An item the catalogue wrote no question for
    // is simply not asked about.
    test('skips items with no question from the server', () {
      final selected = selectCalibrarPlans([
        _plan('rodizio_pneus', priority: 30, question: null),
        _plan('troca_oleo', priority: 100),
      ]);

      expect([for (final plan in selected) plan.itemSlug], ['troca_oleo']);
    });

    test('asks nothing about an item the vehicle does not have', () {
      // The server already leaves these out of the list this reads. Belt and
      // braces: if one ever arrives, it must not become a question.
      final selected = selectCalibrarPlans([
        _plan(
          'correia_dentada',
          priority: 80,
          status: MaintenanceStatus.naoSeAplica,
        ),
      ]);

      expect(selected, isEmpty);
    });

    test('uses the question the server wrote, never one of its own', () {
      final plan = _plan(
        'troca_oleo',
        priority: 100,
        question: 'Quando foi a última troca de óleo?',
      );
      expect(calibrarQuestionTitle(plan), 'Quando foi a última troca de óleo?');
    });
  });

  group('declaredBaselineDraft', () {
    test(
      'builds a declared record with one item and no workshop or amount',
      () {
        const occurredOn = CivilDate(2026, 3, 10);
        final plan = _plan('troca_oleo', priority: 100);
        final body = declaredBaselineDraft(
          id: _recordId,
          occurredOn: occurredOn,
          mileageKm: 41200,
          plan: plan,
        ).toJson();

        expect(body['id'], _recordId);
        expect(body['occurred_on'], '2026-03-10');
        expect(body['mileage_km'], 41200);
        expect(body['kind'], 'declared');
        expect(body.containsKey('workshop_name'), isFalse);
        expect(body.containsKey('total_cost_cents'), isFalse);
        expect(body.containsKey('notes'), isFalse);
        expect(body['items'], [
          {'maintenance_item_id': plan.maintenanceItemId},
        ]);
      },
    );

    test('never sends performed for a memory answer', () {
      final body = declaredBaselineDraft(
        id: _recordId,
        occurredOn: const CivilDate(2025, 12, 1),
        mileageKm: 1000,
        plan: _plan('pneus', priority: 85),
      ).toJson();

      expect(body['kind'], isNot(MaintenanceRecordKind.performed.name));
      expect(body['kind'], 'declared');
    });
  });
}

const _recordId = '11111111-1111-7111-8111-111111111111';

MaintenancePlan _plan(
  String slug, {
  required int priority,
  MaintenanceStatus status = MaintenanceStatus.semBaseline,
  MaintenanceHistoryStatus historyStatus = MaintenanceHistoryStatus.notAsked,
  String? question = 'Quando foi a última vez?',
}) {
  return MaintenancePlan(
    id: 'plan-$slug',
    maintenanceItemId: 'item-$slug',
    itemSlug: slug,
    itemName: slug,
    itemKind: MaintenanceItemKind.maintenance,
    alertKm: 500,
    alertDays: 15,
    origin: MaintenancePlanOrigin.suggested,
    strategy: MaintenanceStrategy.periodic,
    historyStatus: historyStatus,
    historyQuestion: question,
    historyPriority: priority,
    status: status,
  );
}
