import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/odometer/domain/odometer_reading.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

/// What `POST /odometer` answers with: the reading, and the vehicle already
/// carrying the new mileage.
///
/// The vehicle comes back precisely so the client does not have to ask again,
/// and reusing [Vehicle] rather than declaring a second model keeps one parser
/// for one payload.
final class OdometerCreated {
  const OdometerCreated({required this.reading, required this.vehicle});

  final OdometerReading reading;
  final Vehicle vehicle;
}

final class OdometerRepository {
  OdometerRepository({required this.api, String Function()? newId})
    : _newId = newId ?? newClientId;

  final ApiClient api;
  final String Function() _newId;

  /// [force] resends the reading as a correction, which is how the server lets
  /// a rejected value through. Only ever set from an explicit choice by the
  /// owner — never automatically, because the whole point of the rejection is
  /// that a person has to look at it.
  Future<OdometerCreated> create({
    required String vehicleId,
    required int mileageKm,
    CivilDate? occurredOn,
    String? notes,
    bool force = false,
    String? id,
  }) async {
    final body = await api.post(
      ApiPaths.vehicleOdometer(vehicleId),
      body: {
        'id': id ?? _newId(),
        'mileage_km': mileageKm,
        if (occurredOn != null) 'occurred_on': occurredOn.toJson(),
        'source': force ? 'correction' : 'manual',
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return OdometerCreated(
      reading: OdometerReading.fromJson(
        Map<String, dynamic>.from(body['reading'] as Map),
      ),
      vehicle: Vehicle.fromJson(
        Map<String, dynamic>.from(body['vehicle'] as Map),
      ),
    );
  }

  Future<CursorPage<OdometerReading>> list(
    String vehicleId, {
    int? limit,
    String? cursor,
  }) async {
    final body = await api.get(
      ApiPaths.vehicleOdometer(vehicleId),
      query: api.paginationQuery(limit: limit, cursor: cursor),
    );
    return pageOf(body, OdometerReading.fromJson);
  }

  /// A permanent delete, unlike a vehicle. A mistyped reading is noise, not
  /// history, and leaving it would corrupt every interval derived from it.
  Future<void> delete(String readingId) async {
    await api.delete(ApiPaths.odometer(readingId));
  }
}
