import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';

/// Presentation grouping of a list the server already ordered by urgency.
///
/// Within each group the incoming order is kept. A care item that is overdue
/// or due soon stays in those groups so the urgent reading is one list; the
/// remaining care items get their own section rather than mixing with
/// maintenance that is on track or still missing a baseline.
///
/// Items the vehicle does not have never arrive here at all — the list this is
/// built from excludes them at the server. There is no group for them and there
/// must not be one: a hidden or disabled card is still a card about a component
/// the car does not have.
final class CuidadosGroups {
  const CuidadosGroups({
    required this.needAttention,
    required this.dueSoon,
    required this.everydayCare,
    required this.onTrack,
    required this.needsBaseline,
    required this.historySettled,
    required this.historyOnly,
  });

  final List<MaintenancePlan> needAttention;
  final List<MaintenancePlan> dueSoon;
  final List<MaintenancePlan> everydayCare;
  final List<MaintenancePlan> onTrack;

  /// Nobody has been asked about these yet. This is the only group that carries
  /// a prompt.
  final List<MaintenancePlan> needsBaseline;

  /// Asked and answered — "não sei" or "nunca foi feito". Still no baseline, so
  /// still nothing to count from, but the question has been dealt with and must
  /// stop being asked. Collapsed, and never a prompt.
  final List<MaintenancePlan> historySettled;

  final List<MaintenancePlan> historyOnly;

  bool get isEmpty =>
      needAttention.isEmpty &&
      dueSoon.isEmpty &&
      everydayCare.isEmpty &&
      onTrack.isEmpty &&
      needsBaseline.isEmpty &&
      historySettled.isEmpty &&
      historyOnly.isEmpty;
}

CuidadosGroups groupCuidadosPlans(List<MaintenancePlan> plans) {
  final needAttention = <MaintenancePlan>[];
  final dueSoon = <MaintenancePlan>[];
  final everydayCare = <MaintenancePlan>[];
  final onTrack = <MaintenancePlan>[];
  final needsBaseline = <MaintenancePlan>[];
  final historySettled = <MaintenancePlan>[];
  final historyOnly = <MaintenancePlan>[];

  for (final plan in plans) {
    // Defensive: the server already leaves these out of this list. If one ever
    // arrives — an older build talking to a newer server, a caller that passed
    // the wrong list — it must not become a card.
    if (plan.status == MaintenanceStatus.naoSeAplica) {
      continue;
    }
    if (plan.status == MaintenanceStatus.vencido) {
      needAttention.add(plan);
      continue;
    }
    if (plan.status == MaintenanceStatus.venceEmBreve) {
      dueSoon.add(plan);
      continue;
    }
    if (plan.itemKind == MaintenanceItemKind.care) {
      everydayCare.add(plan);
      continue;
    }
    if (plan.status == MaintenanceStatus.semBaseline) {
      if (plan.historyStatus == MaintenanceHistoryStatus.notAsked) {
        needsBaseline.add(plan);
      } else {
        historySettled.add(plan);
      }
      continue;
    }
    if (plan.status == MaintenanceStatus.semPeriodicidade) {
      historyOnly.add(plan);
      continue;
    }
    onTrack.add(plan);
  }

  return CuidadosGroups(
    needAttention: needAttention,
    dueSoon: dueSoon,
    everydayCare: everydayCare,
    onTrack: onTrack,
    needsBaseline: needsBaseline,
    historySettled: historySettled,
    historyOnly: historyOnly,
  );
}
