import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/data/maintenance_item_repository.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/odometer/application/odometer_provider.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';

final maintenanceItemRepositoryProvider = Provider<MaintenanceItemRepository>((
  ref,
) {
  return MaintenanceItemRepository(api: ref.watch(apiClientProvider));
});

/// The catalogue changes rarely and the picker opens often, so it is cached.
///
/// Filtered to `car` (which includes `all`) — motorcycles are not in MVP-1.
/// Both `maintenance` and `care` come back; the picker groups them.
final maintenanceItemsProvider = FutureProvider<List<MaintenanceItem>>((ref) {
  return ref.watch(maintenanceItemRepositoryProvider).list(vehicleType: 'car');
});

/// What a successful record write has to refresh.
///
/// The dashboard and the plans list both carry due dates the server
/// recomputes; the odometer history is here because the record produced a
/// reading.
void invalidateAfterMaintenanceWrite(WidgetRef ref, String vehicleId) {
  ref.invalidate(dashboardProvider(vehicleId));
  ref.invalidate(maintenancePlansProvider(vehicleId));
  ref.invalidate(maintenanceRecordsProvider(vehicleId));
  ref.invalidate(odometerHistoryProvider(vehicleId));
  ref.invalidate(timelineProvider(vehicleId));
  ref.invalidate(costsDashboardProvider);
}
