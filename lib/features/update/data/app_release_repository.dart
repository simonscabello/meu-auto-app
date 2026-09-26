import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/update/domain/app_release.dart';

/// Asks the server which build the app can update to. One public GET.
final class AppReleaseRepository {
  AppReleaseRepository({required this.api});

  final ApiClient api;

  /// Null when nothing is announced, or when what arrived cannot be used.
  Future<AppRelease?> latest() async {
    final body = await api.get(ApiPaths.appVersion);
    return AppRelease.fromJson(body);
  }
}
