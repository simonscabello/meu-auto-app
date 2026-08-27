import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';

final class AbastecimentoRepository {
  AbastecimentoRepository({required this.api, String Function()? newId})
    : _newId = newId ?? newClientId;

  final ApiClient api;
  final String Function() _newId;

  Future<CursorPage<Abastecimento>> list(
    String vehicleId, {
    int? limit,
    String? cursor,
  }) async {
    final body = await api.get(
      ApiPaths.vehicleAbastecimentos(vehicleId),
      query: api.paginationQuery(limit: limit, cursor: cursor),
    );
    return pageOf(body, Abastecimento.fromJson);
  }

  Future<Abastecimento> get(String id) async {
    final body = await api.get(ApiPaths.abastecimento(id));
    return Abastecimento.fromJson(body);
  }

  /// [force] resends the mileage as a correction. Only ever set from the
  /// rollback dialog — never automatically.
  Future<Abastecimento> create({
    required String vehicleId,
    required int mileageKm,
    required int volumeMl,
    required int totalCostCents,
    required AbastecimentoFuel fuel,
    CivilDate? occurredOn,
    bool fullTank = true,
    String? stationName,
    String? notes,
    bool force = false,
    String? id,
  }) async {
    final body = await api.post(
      ApiPaths.vehicleAbastecimentos(vehicleId),
      body: {
        'id': id ?? _newId(),
        'mileage_km': mileageKm,
        'volume_ml': volumeMl,
        'total_cost_cents': totalCostCents,
        'fuel': fuel.wire,
        if (occurredOn != null) 'occurred_on': occurredOn.toJson(),
        'full_tank': fullTank,
        if (stationName != null && stationName.trim().isNotEmpty)
          'station_name': stationName.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'source': force ? 'correction' : 'manual',
      },
    );
    return Abastecimento.fromJson(body);
  }

  Future<Abastecimento> update(
    String id, {
    CivilDate? occurredOn,
    int? mileageKm,
    int? volumeMl,
    int? totalCostCents,
    AbastecimentoFuel? fuel,
    bool? fullTank,
    String? stationName,
    String? notes,
    bool force = false,
  }) async {
    final body = await api.patch(
      ApiPaths.abastecimento(id),
      body: {
        if (occurredOn != null) 'occurred_on': occurredOn.toJson(),
        'mileage_km': ?mileageKm,
        'volume_ml': ?volumeMl,
        'total_cost_cents': ?totalCostCents,
        if (fuel != null) 'fuel': fuel.wire,
        'full_tank': ?fullTank,
        'station_name': ?stationName,
        'notes': ?notes,
        if (force) 'source': 'correction',
      },
    );
    return Abastecimento.fromJson(body);
  }

  Future<void> delete(String id) async {
    await api.delete(ApiPaths.abastecimento(id));
  }
}
