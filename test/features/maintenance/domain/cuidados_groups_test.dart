import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/maintenance/domain/cuidados_groups.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';

void main() {
  test('the five statuses land in distinct groups, server order kept', () {
    final overdueLate = _plan(
      id: '1',
      name: 'Correia dentada',
      status: MaintenanceStatus.vencido,
    );
    final overdueSooner = _plan(
      id: '2',
      name: 'Troca de óleo do motor',
      status: MaintenanceStatus.vencido,
    );
    final dueSoon = _plan(
      id: '3',
      name: 'Alinhamento',
      status: MaintenanceStatus.venceEmBreve,
    );
    final onTrack = _plan(
      id: '4',
      name: 'Velas',
      status: MaintenanceStatus.emDia,
    );
    final baseline = _plan(
      id: '5',
      name: 'Filtro de ar do motor',
      status: MaintenanceStatus.semBaseline,
    );
    final history = _plan(
      id: '6',
      name: 'Personalizada',
      status: MaintenanceStatus.semPeriodicidade,
    );

    // Server order: urgency, then closeness. The two overdue items arrive
    // already sorted — the group must not alphabetise them.
    final groups = groupCuidadosPlans([
      overdueLate,
      overdueSooner,
      dueSoon,
      baseline,
      onTrack,
      history,
    ]);

    expect(groups.needAttention.map((plan) => plan.id), ['1', '2']);
    expect(groups.dueSoon.map((plan) => plan.id), ['3']);
    expect(groups.needsBaseline.map((plan) => plan.id), ['5']);
    expect(groups.onTrack.map((plan) => plan.id), ['4']);
    expect(groups.historyOnly.map((plan) => plan.id), ['6']);
    expect(groups.everydayCare, isEmpty);
  });

  test('care that is not urgent gets its own group, even if em_dia', () {
    final overdueCare = _plan(
      id: 'c1',
      name: 'Calibrar os pneus',
      kind: MaintenanceItemKind.care,
      status: MaintenanceStatus.vencido,
    );
    final dueSoonCare = _plan(
      id: 'c2',
      name: 'Verificar o óleo',
      kind: MaintenanceItemKind.care,
      status: MaintenanceStatus.venceEmBreve,
    );
    final everyday = _plan(
      id: 'c3',
      name: 'Lavar o carro',
      kind: MaintenanceItemKind.care,
      status: MaintenanceStatus.emDia,
    );
    final careBaseline = _plan(
      id: 'c4',
      name: 'Verificar os pneus',
      kind: MaintenanceItemKind.care,
      status: MaintenanceStatus.semBaseline,
    );
    final maintenanceBaseline = _plan(
      id: 'm1',
      name: 'Troca de óleo do motor',
      status: MaintenanceStatus.semBaseline,
    );

    final groups = groupCuidadosPlans([
      overdueCare,
      dueSoonCare,
      careBaseline,
      everyday,
      maintenanceBaseline,
    ]);

    expect(groups.needAttention.map((plan) => plan.id), ['c1']);
    expect(groups.dueSoon.map((plan) => plan.id), ['c2']);
    expect(groups.everydayCare.map((plan) => plan.id), ['c4', 'c3']);
    expect(groups.needsBaseline.map((plan) => plan.id), ['m1']);
    expect(groups.onTrack, isEmpty);
  });

  test('an empty list yields empty groups', () {
    expect(groupCuidadosPlans(const []).isEmpty, isTrue);
  });
}

MaintenancePlan _plan({
  required String id,
  required String name,
  required MaintenanceStatus status,
  MaintenanceItemKind kind = MaintenanceItemKind.maintenance,
}) {
  return MaintenancePlan(
    id: id,
    maintenanceItemId: 'item-$id',
    itemSlug: name.toLowerCase().replaceAll(' ', '_'),
    itemName: name,
    itemKind: kind,
    alertKm: 500,
    alertDays: 15,
    origin: MaintenancePlanOrigin.suggested,
    status: status,
  );
}
