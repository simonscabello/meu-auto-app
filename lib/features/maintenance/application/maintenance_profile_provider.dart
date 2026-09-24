import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/maintenance/data/maintenance_profile_repository.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/vehicle/application/vehicle_derived.dart';

final maintenanceProfileRepositoryProvider =
    Provider<MaintenanceProfileRepository>((ref) {
      return MaintenanceProfileRepository(api: ref.watch(apiClientProvider));
    });

/// The vehicle's profile: what it needs and what is still open.
final maintenanceProfileProvider =
    FutureProvider.family<MaintenanceProfile, String>((ref, vehicleId) {
      return ref.watch(maintenanceProfileRepositoryProvider).get(vehicleId);
    });

/// Answering a question changes which plans exist, so both plan lists reload —
/// and so does the dashboard, whose prompt counts the open questions.
void invalidateAfterProfileWrite(WidgetRef ref, String vehicleId) {
  invalidateVehicleDerived(ref, vehicleId);
}
