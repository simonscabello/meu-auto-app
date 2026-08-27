import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/maintenance/data/maintenance_plan_repository.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';

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

/// One plan by id. Tries the member route first; an older server that 404s
/// still has the row in the vehicle list.
final maintenancePlanProvider =
    FutureProvider.family<MaintenancePlan, ({String vehicleId, String planId})>((
      ref,
      args,
    ) {
      return ref
          .watch(maintenancePlanRepositoryProvider)
          .getWithFallback(planId: args.planId, vehicleId: args.vehicleId);
    });

void invalidateAfterPlanWrite(WidgetRef ref, String vehicleId) {
  ref.invalidate(maintenancePlansProvider(vehicleId));
  ref.invalidate(maintenancePlansWithHiddenProvider(vehicleId));
  ref.invalidate(maintenancePlanProvider);
  ref.invalidate(dashboardProvider(vehicleId));
}
