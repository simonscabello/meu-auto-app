import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';

final class MaintenanceRecordRepository {
  MaintenanceRecordRepository({required this.api});

  final ApiClient api;

  Future<CursorPage<MaintenanceRecord>> list(
    String vehicleId, {
    int? limit,
    String? cursor,
  }) async {
    final body = await api.get(
      ApiPaths.vehicleMaintenanceRecords(vehicleId),
      query: api.paginationQuery(limit: limit, cursor: cursor),
    );
    return pageOf(body, MaintenanceRecord.fromJson);
  }

  Future<MaintenanceRecord> get(String recordId) async {
    final body = await api.get(ApiPaths.maintenanceRecord(recordId));
    return MaintenanceRecord.fromJson(body);
  }

  /// 200 (retry of the same client `id`) and 201 are the same success.
  Future<MaintenanceRecord> create(
    String vehicleId,
    MaintenanceRecordDraft draft,
  ) async {
    final body = await api.post(
      ApiPaths.vehicleMaintenanceRecords(vehicleId),
      body: draft.toJson(),
    );
    return MaintenanceRecord.fromJson(body);
  }

  /// Edits the event, never its item lines.
  ///
  /// The contract does not allow changing items, and for a good reason:
  /// removing one would have to decide what happens to the clock it was
  /// keeping. An absent field stays as it is.
  ///
  /// Moving the date or the mileage moves the odometer reading this record
  /// produced, so this call goes through the same consistency check as the
  /// odometer endpoint and can answer `odometer_rollback`.
  Future<MaintenanceRecord> update(
    String recordId, {
    CivilDate? occurredOn,
    int? mileageKm,
    String? workshopName,
    Money? totalCost,
    String? notes,
  }) async {
    final body = await api.patch(
      ApiPaths.maintenanceRecord(recordId),
      body: {
        'occurred_on': ?occurredOn?.toJson(),
        'mileage_km': ?mileageKm,
        'workshop_name': ?workshopName,
        'total_cost_cents': ?totalCost?.cents,
        'notes': ?notes,
      },
    );
    return MaintenanceRecord.fromJson(body);
  }

  /// Appends lines to a record that already exists.
  ///
  /// The forgotten brake fluid on a revisão that was otherwise complete. It
  /// touches nothing about the event — not the date, not the mileage, not the
  /// total — so unlike [update] it cannot answer `odometer_rollback`: the
  /// reading this record produced does not move.
  ///
  /// The whole record comes back, lines included, so the caller replaces what
  /// it is showing instead of stitching a partial answer onto it.
  Future<MaintenanceRecord> addItems(
    String recordId,
    List<MaintenanceRecordLineDraft> lines,
  ) async {
    final body = await api.post(
      ApiPaths.maintenanceRecordItems(recordId),
      body: {'items': [for (final line in lines) line.toJson()]},
    );
    return MaintenanceRecord.fromJson(body);
  }

  /// Retracts the record.
  ///
  /// A logical delete on the server, and it undoes what the record caused: the
  /// odometer reading it generated goes with it, and the clock of every item
  /// involved falls back to the previous record.
  Future<void> delete(String recordId) async {
    await api.delete(ApiPaths.maintenanceRecord(recordId));
  }
}
