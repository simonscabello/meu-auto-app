import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';

final class MaintenanceItemRepository {
  MaintenanceItemRepository({required this.api});

  final ApiClient api;

  Future<List<MaintenanceItem>> list({
    String? vehicleType,
    MaintenanceItemKind? kind,
  }) async {
    final body = await api.get(
      ApiPaths.maintenanceItems,
      query: {'vehicle_type': ?vehicleType, 'kind': ?kind?.wire},
    );
    return listOf(body, MaintenanceItem.fromJson);
  }

  /// Visible only to the owner. The server derives the slug from the name,
  /// and there is no client `id` — a retry after a timeout can 409.
  Future<MaintenanceItem> createCustom({
    required String name,
    MaintenanceItemKind kind = MaintenanceItemKind.maintenance,
    int? intervalKm,
    int? intervalMonths,
    int? intervalDays,
  }) async {
    final body = await api.post(
      ApiPaths.maintenanceItems,
      body: {
        'name': name.trim(),
        'kind': ?kind.wire,
        'default_interval_km': ?intervalKm,
        'default_interval_months': ?intervalMonths,
        'default_interval_days': ?intervalDays,
      },
    );
    return MaintenanceItem.fromJson(body);
  }
}
