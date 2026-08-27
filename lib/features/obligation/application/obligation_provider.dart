import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/obligation/data/obligation_repository.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';

final obligationRepositoryProvider = Provider<ObligationRepository>((ref) {
  return ObligationRepository(api: ref.watch(apiClientProvider));
});

final obligationsProvider = FutureProvider.family<List<Obligation>, String>((
  ref,
  vehicleId,
) {
  return ref.watch(obligationRepositoryProvider).listObligations(vehicleId);
});

final segurosProvider = FutureProvider.family<List<Seguro>, String>((
  ref,
  vehicleId,
) {
  return ref.watch(obligationRepositoryProvider).listSeguros(vehicleId);
});

/// One débito, fetched on its own so an alert or a deep link does not have
/// to wait for the vehicle's full list.
final obligationProvider = FutureProvider.family<Obligation, String>((
  ref,
  obligationId,
) {
  return ref.watch(obligationRepositoryProvider).getObligation(obligationId);
});

final seguroProvider = FutureProvider.family<Seguro, String>((ref, seguroId) {
  return ref.watch(obligationRepositoryProvider).getSeguro(seguroId);
});

void invalidateAfterObligationWrite(WidgetRef ref, String vehicleId) {
  ref.invalidate(obligationsProvider(vehicleId));
  ref.invalidate(obligationProvider);
  ref.invalidate(dashboardProvider(vehicleId));
  ref.invalidate(timelineProvider(vehicleId));
  ref.invalidate(costsDashboardProvider);
}

void invalidateAfterSeguroWrite(WidgetRef ref, String vehicleId) {
  ref.invalidate(segurosProvider(vehicleId));
  ref.invalidate(seguroProvider);
  ref.invalidate(dashboardProvider(vehicleId));
  ref.invalidate(timelineProvider(vehicleId));
  ref.invalidate(costsDashboardProvider);
}
