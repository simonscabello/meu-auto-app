import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/onboarding/domain/calibrar_questions.dart';

void main() {
  group('selectCalibrarPlans', () {
    test(
      'keeps only sem_baseline plans, in presentation order, capped at five',
      () {
        final selected = selectCalibrarPlans([
          _plan('palhetas', MaintenanceStatus.semBaseline),
          _plan('alinhamento', MaintenanceStatus.semBaseline),
          _plan('filtro_ar', MaintenanceStatus.semBaseline),
          _plan('correia_dentada', MaintenanceStatus.semBaseline),
          _plan('bateria', MaintenanceStatus.emDia),
          _plan('pneus', MaintenanceStatus.semBaseline),
          _plan('revisao', MaintenanceStatus.vencido),
          _plan('troca_oleo', MaintenanceStatus.semBaseline),
          _plan('velas', MaintenanceStatus.semBaseline),
        ]);

        expect(
          [for (final plan in selected) plan.itemSlug],
          [
            'troca_oleo',
            'pneus',
            'correia_dentada',
            'filtro_ar',
            'alinhamento',
          ],
        );
      },
    );

    test('returns fewer than five when that is all that is missing', () {
      final selected = selectCalibrarPlans([
        _plan('revisao', MaintenanceStatus.semBaseline),
        _plan('troca_oleo', MaintenanceStatus.emDia),
      ]);

      expect([for (final plan in selected) plan.itemSlug], ['revisao']);
    });

    test('returns nothing when no priority plan still needs a date', () {
      expect(
        selectCalibrarPlans([
          _plan('palhetas', MaintenanceStatus.semBaseline),
          _plan('troca_oleo', MaintenanceStatus.emDia),
        ]),
        isEmpty,
      );
    });
  });

  group('declaredBaselineDraft', () {
    test(
      'builds a declared record with one item and no workshop or amount',
      () {
        const occurredOn = CivilDate(2026, 3, 10);
        final plan = _plan('troca_oleo', MaintenanceStatus.semBaseline);
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
        plan: _plan('pneus', MaintenanceStatus.semBaseline),
      ).toJson();

      expect(body['kind'], isNot(MaintenanceRecordKind.performed.name));
      expect(body['kind'], 'declared');
    });
  });
}

const _recordId = '11111111-1111-7111-8111-111111111111';

MaintenancePlan _plan(String slug, MaintenanceStatus status) {
  return MaintenancePlan(
    id: 'plan-$slug',
    maintenanceItemId: 'item-$slug',
    itemSlug: slug,
    itemName: slug,
    itemKind: MaintenanceItemKind.maintenance,
    alertKm: 500,
    alertDays: 15,
    origin: MaintenancePlanOrigin.suggested,
    status: status,
  );
}
