import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';

/// Presentation ranking of which plans to ask first after a vehicle is
/// registered.
///
/// The server does not rank importance. This order is display only — it is
/// not a business rule and must not be treated as one.
const calibrarPrioritySlugs = <String>[
  'troca_oleo',
  'revisao',
  'pneus',
  'bateria',
  'correia_dentada',
  'filtro_ar',
  'alinhamento',
];

const calibrarMaxQuestions = 5;

const calibrarQuestionSubtitle = 'Para o Meu Auto saber quando avisar você.';

List<MaintenancePlan> selectCalibrarPlans(Iterable<MaintenancePlan> plans) {
  final missing = <String, MaintenancePlan>{};
  for (final plan in plans) {
    if (plan.status != MaintenanceStatus.semBaseline) continue;
    missing.putIfAbsent(plan.itemSlug, () => plan);
  }

  final selected = <MaintenancePlan>[];
  for (final slug in calibrarPrioritySlugs) {
    final plan = missing[slug];
    if (plan == null) continue;
    selected.add(plan);
    if (selected.length == calibrarMaxQuestions) break;
  }
  return selected;
}

String calibrarQuestionTitle(MaintenancePlan plan) {
  return switch (plan.itemSlug) {
    'troca_oleo' => 'Quando foi a última troca de óleo?',
    'revisao' => 'Quando foi a última revisão?',
    'pneus' => 'Quando foi a última troca de pneus?',
    'bateria' => 'Quando foi a última troca da bateria?',
    'correia_dentada' => 'Quando foi a última troca da correia dentada?',
    'filtro_ar' => 'Quando foi a última troca do filtro de ar?',
    'alinhamento' => 'Quando foi o último alinhamento?',
    _ => 'Quando foi a última vez?',
  };
}

/// A memory answer for one plan: [kind] declared, one line, no shop, no amount.
MaintenanceRecordDraft declaredBaselineDraft({
  required String id,
  required CivilDate occurredOn,
  required int mileageKm,
  required MaintenancePlan plan,
}) {
  return MaintenanceRecordDraft(
    id: id,
    occurredOn: occurredOn,
    mileageKm: mileageKm,
    kind: MaintenanceRecordKind.declared,
    items: [MaintenanceRecordLineDraft(item: plan.toCatalogueItem())],
  );
}
