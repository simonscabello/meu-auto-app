import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';

final class MaintenanceProfileRepository {
  const MaintenanceProfileRepository({required this.api});

  final ApiClient api;

  Future<MaintenanceProfile> get(String vehicleId) async {
    final body = await api.get(ApiPaths.vehicleMaintenanceProfile(vehicleId));
    return MaintenanceProfile.fromJson(body);
  }

  /// Answers one question and returns the profile the answer produced.
  ///
  /// The whole profile comes back rather than an acknowledgement, because an
  /// answer changes which plans exist — a second round trip to find out would
  /// leave a window where the screen and the server disagree.
  Future<MaintenanceProfile> answer(
    String vehicleId, {
    required String question,
    required String answer,
  }) async {
    final body = await api.post(
      ApiPaths.vehicleMaintenanceProfileAnswers(vehicleId),
      body: {'question': question, 'answer': answer},
    );
    return MaintenanceProfile.fromJson(body);
  }
}
