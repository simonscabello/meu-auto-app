import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/data/maintenance_item_repository.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/vehicle/application/vehicle_derived.dart';

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

/// What a successful record write has to refresh: everything derived from
/// the vehicle's history (a record resets clocks and may move the odometer),
/// plus the record lists and any record detail that is open.
void invalidateAfterMaintenanceWrite(WidgetRef ref, String vehicleId) {
  invalidateVehicleDerived(ref, vehicleId);
  ref.invalidate(maintenanceRecordsProvider(vehicleId));
  ref.invalidate(maintenanceRecordProvider);
}
