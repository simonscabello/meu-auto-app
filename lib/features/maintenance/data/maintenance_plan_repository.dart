import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';

final class MaintenancePlanRepository {
  MaintenancePlanRepository({required this.api, String Function()? newId})
    : _newId = newId ?? newClientId;

  final ApiClient api;
  final String Function() _newId;

  Future<List<MaintenancePlan>> list(String vehicleId) async {
    final body = await api.get(ApiPaths.vehicleMaintenancePlans(vehicleId));
    return listOf(body, MaintenancePlan.fromJson);
  }

  /// 200 (retry of the same client `id`) and 201 are the same success.
  Future<MaintenancePlanSummary> create({
    required String vehicleId,
    required String maintenanceItemId,
    String? id,
    int? intervalKm,
    int? intervalMonths,
    int? intervalDays,
    int? alertKm,
    int? alertDays,
  }) async {
    final body = await api.post(
      ApiPaths.vehicleMaintenancePlans(vehicleId),
      body: {
        'id': id ?? _newId(),
        'maintenance_item_id': maintenanceItemId,
        'interval_km': ?intervalKm,
        'interval_months': ?intervalMonths,
        'interval_days': ?intervalDays,
        'alert_km': ?alertKm,
        'alert_days': ?alertDays,
      },
    );
    return MaintenancePlanSummary.fromJson(body);
  }

  Future<MaintenancePlanSummary> update(String planId, PlanUpdate patch) async {
    final body = await api.patch(
      ApiPaths.maintenancePlan(planId),
      body: patch.toJson(),
    );
    return MaintenancePlanSummary.fromJson(body);
  }

  /// Soft-deletes: the plan may already have history attached.
  Future<void> deactivate(String planId) async {
    await api.delete(ApiPaths.maintenancePlan(planId));
  }
}
