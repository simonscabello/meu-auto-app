import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/dashboard/data/dashboard_repository.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(api: ref.watch(apiClientProvider));
});

/// The dashboard for one vehicle.
///
/// Keyed by vehicle id so switching cars is a different provider rather than a
/// refetch of the same one — the previous car's data stays cached and comes
/// back instantly when the owner switches back.
///
/// Anything that writes (odometer, maintenance, prazos) invalidates this.
final dashboardProvider = FutureProvider.family<Dashboard, String>((
  ref,
  vehicleId,
) {
  return ref.watch(dashboardRepositoryProvider).get(vehicleId);
});
