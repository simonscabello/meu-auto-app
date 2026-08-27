import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/application/paged_family_controller.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/maintenance/data/maintenance_record_repository.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';

final maintenanceRecordRepositoryProvider =
    Provider<MaintenanceRecordRepository>((ref) {
      return MaintenanceRecordRepository(api: ref.watch(apiClientProvider));
    });

/// The service history of one vehicle, newest first.
final maintenanceRecordsProvider =
    AsyncNotifierProvider.family<
      MaintenanceRecordsController,
      PagedState<MaintenanceRecord>,
      String
    >(MaintenanceRecordsController.new);

class MaintenanceRecordsController
    extends PagedFamilyController<MaintenanceRecord, String> {
  @override
  Future<CursorPage<MaintenanceRecord>> fetchPage({
    required String arg,
    required int limit,
    String? cursor,
  }) {
    return ref
        .read(maintenanceRecordRepositoryProvider)
        .list(arg, limit: limit, cursor: cursor);
  }

  /// Retracts a record and drops it from the loaded list.
  ///
  /// The caller refreshes what derives from it — the dashboard and the vehicle,
  /// because the odometer reading this record produced goes away with it.
  Future<void> retract(String recordId) async {
    await ref.read(maintenanceRecordRepositoryProvider).delete(recordId);
    removeWhere((record) => record.id == recordId);
  }
}

/// One record, fetched on its own.
///
/// The list already embeds full items, so opening a record the list loaded
/// costs nothing extra — but a record reached from an alert or a deep link has
/// no list behind it, and this is how it arrives.
final maintenanceRecordProvider =
    FutureProvider.family<MaintenanceRecord, String>((ref, recordId) {
      return ref.read(maintenanceRecordRepositoryProvider).get(recordId);
    });
