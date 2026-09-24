import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/application/paged_family_controller.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/abastecimento/data/abastecimento_repository.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/vehicle/application/vehicle_derived.dart';
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

/// A fill carries a mileage, so it moves every distance-based due date — the
/// plan list and the plan detail as much as Início.
void invalidateAfterAbastecimentoWrite(WidgetRef ref, String vehicleId) {
  ref.invalidate(abastecimentoHistoryProvider(vehicleId));
  ref.invalidate(abastecimentoProvider);
  invalidateVehicleDerived(ref, vehicleId);
  ref.read(vehiclesProvider.notifier).reload();
}
