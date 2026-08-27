import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';

/// Which history questions to ask, and in what order.
///
/// Both come from the server now. This file used to hold a list of technical
/// slugs and a `switch` writing a pt-BR question for each — which is exactly how
/// every car, including the ones with a timing chain and the ones with no engine
/// at all, ended up being asked when its timing belt was last changed.
///
/// What is left here is presentation: a cap on how many to ask at once, and the
/// draft shape for an answer.
const calibrarMaxQuestions = 5;

const calibrarQuestionSubtitle = 'Para o Meu Auto saber quando avisar você.';

/// The plans worth asking about, most important first.
///
/// Three filters, and each one removes a question that should never be asked:
///
///  * only items with no baseline — there is nothing to ask about the rest;
///  * only items nobody has been asked about — a "não sei" already given is an
///    answer, and repeating the question is how a helpful prompt becomes
///    nagging;
///  * only items the catalogue wrote a question for. Nothing here invents
///    wording, so an item with no question is simply not asked about.
///
/// Items the vehicle does not have never reach this list: the server leaves them
/// out of the plan list entirely.
List<MaintenancePlan> selectCalibrarPlans(Iterable<MaintenancePlan> plans) {
  final askable = <MaintenancePlan>[];
  final seen = <String>{};

  for (final plan in plans) {
    if (plan.status != MaintenanceStatus.semBaseline) continue;
    if (plan.historyStatus != MaintenanceHistoryStatus.notAsked) continue;
    final question = plan.historyQuestion?.trim();
    if (question == null || question.isEmpty) continue;
    if (!seen.add(plan.itemSlug)) continue;
    askable.add(plan);
  }

  // Highest priority first; the server's own order (urgency, then name) breaks
  // ties, so the result is stable.
  askable.sort((a, b) => b.historyPriority.compareTo(a.historyPriority));

  if (askable.length <= calibrarMaxQuestions) return askable;
  return askable.sublist(0, calibrarMaxQuestions);
}

/// The question, as the catalogue wrote it.
String calibrarQuestionTitle(MaintenancePlan plan) {
  final question = plan.historyQuestion?.trim();
  if (question != null && question.isNotEmpty) return question;
  // Never reached through [selectCalibrarPlans], which filters these out. Kept
  // so a plan opened from elsewhere still renders something honest.
  return 'Quando foi a última vez?';
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
