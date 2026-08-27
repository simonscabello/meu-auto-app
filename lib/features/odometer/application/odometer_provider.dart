import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/application/paged_family_controller.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/odometer/data/odometer_repository.dart';
import 'package:meu_auto/features/odometer/domain/odometer_reading.dart';

final odometerRepositoryProvider = Provider<OdometerRepository>((ref) {
  return OdometerRepository(api: ref.watch(apiClientProvider));
});

/// The mileage history of one vehicle, newest first, one cursor page at a time.
final odometerHistoryProvider =
    AsyncNotifierProvider.family<
      OdometerHistoryController,
      PagedState<OdometerReading>,
      String
    >(OdometerHistoryController.new);

class OdometerHistoryController
    extends PagedFamilyController<OdometerReading, String> {
  @override
  Future<CursorPage<OdometerReading>> fetchPage({
    required String arg,
    required int limit,
    String? cursor,
  }) {
    return ref
        .read(odometerRepositoryProvider)
        .list(arg, limit: limit, cursor: cursor);
  }

  /// Deletes a reading and drops it from the loaded list.
  ///
  /// The caller is responsible for refreshing whatever derives from mileage —
  /// removing a reading can change the vehicle's current mileage, which moves
  /// every distance-based due date with it.
  Future<void> remove(String readingId) async {
    await ref.read(odometerRepositoryProvider).delete(readingId);
    removeWhere((reading) => reading.id == readingId);
  }
}
