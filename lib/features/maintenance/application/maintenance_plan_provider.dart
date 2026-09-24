import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/maintenance/data/maintenance_plan_repository.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/vehicle/application/vehicle_derived.dart';

final maintenancePlanRepositoryProvider = Provider<MaintenancePlanRepository>((
  ref,
) {
  return MaintenancePlanRepository(api: ref.watch(apiClientProvider));
});

/// Plans of one vehicle, already ordered by urgency and with due computed.
///
/// Items the vehicle does not have are not in here, and that is the whole point:
/// no screen built on this provider can accidentally show a timing belt to a car
/// that uses a chain.
final maintenancePlansProvider =
    FutureProvider.family<List<MaintenancePlan>, String>((ref, vehicleId) {
      return ref.watch(maintenancePlanRepositoryProvider).list(vehicleId);
    });

/// The same list plus the items marked as not applicable.
///
/// Two screens need it and no others: the configuration surface, which offers to
/// undo one, and the "new plan" sheet, which must not offer an item the vehicle
/// has already been told it does not have.
final maintenancePlansWithHiddenProvider =
    FutureProvider.family<List<MaintenancePlan>, String>((ref, vehicleId) {
      return ref
          .watch(maintenancePlanRepositoryProvider)
          .list(vehicleId, includeNotApplicable: true);
    });

/// The catalogue items this vehicle does not have, from the list that carries
/// them. Empty while it loads or if it failed: then nothing is hidden, which
/// is the safe side for a form that records what was done.
Set<String> notApplicableItemIds(AsyncValue<List<MaintenancePlan>> plans) {
  final list = plans.valueOrNull;
  if (list == null) return const {};
  return {
    for (final plan in list)
      if (plan.status == MaintenanceStatus.naoSeAplica) plan.maintenanceItemId,
  };
}

/// One plan by id. Tries the member route first; an older server that 404s
/// still has the row in the vehicle list.
final maintenancePlanProvider =
    FutureProvider.family<MaintenancePlan, ({String vehicleId, String planId})>(
      (ref, args) {
        return ref
            .watch(maintenancePlanRepositoryProvider)
            .getWithFallback(planId: args.planId, vehicleId: args.vehicleId);
      },
    );

/// A plan change moves its due date, the verdict on Início and the profile's
/// counts, so it refreshes the same set as any other write on the vehicle.
void invalidateAfterPlanWrite(WidgetRef ref, String vehicleId) {
  invalidateVehicleDerived(ref, vehicleId);
}
