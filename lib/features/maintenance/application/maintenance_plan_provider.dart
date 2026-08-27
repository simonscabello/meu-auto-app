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
final maintenancePlansProvider =
    FutureProvider.family<List<MaintenancePlan>, String>((ref, vehicleId) {
      return ref.watch(maintenancePlanRepositoryProvider).list(vehicleId);
    });

void invalidateAfterPlanWrite(WidgetRef ref, String vehicleId) {
  ref.invalidate(maintenancePlansProvider(vehicleId));
  ref.invalidate(dashboardProvider(vehicleId));
}
