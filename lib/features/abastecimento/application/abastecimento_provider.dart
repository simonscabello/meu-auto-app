import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/application/paged_family_controller.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/abastecimento/data/abastecimento_repository.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/odometer/application/odometer_provider.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';

final abastecimentoRepositoryProvider = Provider<AbastecimentoRepository>((
  ref,
) {
  return AbastecimentoRepository(api: ref.watch(apiClientProvider));
});

/// The fill history of one vehicle, newest first, one cursor page at a time.
final abastecimentoHistoryProvider =
    AsyncNotifierProvider.family<
      AbastecimentoHistoryController,
      PagedState<Abastecimento>,
      String
    >(AbastecimentoHistoryController.new);

class AbastecimentoHistoryController
    extends PagedFamilyController<Abastecimento, String> {
  @override
  Future<CursorPage<Abastecimento>> fetchPage({
    required String arg,
    required int limit,
    String? cursor,
  }) {
    return ref
        .read(abastecimentoRepositoryProvider)
        .list(arg, limit: limit, cursor: cursor);
  }

  Future<void> remove(String fillId) async {
    await ref.read(abastecimentoRepositoryProvider).delete(fillId);
    removeWhere((fill) => fill.id == fillId);
  }
}

/// One fill, fetched on its own so a timeline tap does not wait for the list.
final abastecimentoProvider = FutureProvider.family<Abastecimento, String>((
  ref,
  fillId,
) {
  return ref.watch(abastecimentoRepositoryProvider).get(fillId);
});

void invalidateAfterAbastecimentoWrite(WidgetRef ref, String vehicleId) {
  ref.invalidate(abastecimentoHistoryProvider(vehicleId));
  ref.invalidate(abastecimentoProvider);
  ref.invalidate(dashboardProvider(vehicleId));
  ref.invalidate(timelineProvider(vehicleId));
  ref.invalidate(costsDashboardProvider);
  ref.invalidate(odometerHistoryProvider(vehicleId));
  ref.read(vehiclesProvider.notifier).reload();
}
