import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';

/// The whole Início screen in one request.
///
/// `/dashboard` is a read model: vehicle, odometer, alert counts with the most
/// urgent items already ordered, and the cost summary. There is nothing to
/// compose here and nothing to compute — the server did both.
final class DashboardRepository {
  DashboardRepository({required this.api});

  /// Matches the server default. Sent explicitly so the period selector in the
  /// costs screen has one thing to change and no special case for "default".
  static const defaultCostMonths = 12;

  final ApiClient api;

  Future<Dashboard> get(
    String vehicleId, {
    int costMonths = defaultCostMonths,
  }) async {
    final body = await api.get(
      ApiPaths.vehicleDashboard(vehicleId),
      query: {'cost_months': costMonths},
    );
    return Dashboard.fromJson(body);
  }
}
