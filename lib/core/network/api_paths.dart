import 'package:meu_auto/core/config/app_config.dart';

/// Every route the app is allowed to call, and the only place a path is built.
///
/// This is the app's declared API surface, not a mirror of the contract:
/// `test/contract/openapi_paths_test.dart` reads this file and checks each path
/// against the backend's `openapi.yaml`, so a builder nobody calls only widens
/// what is being asserted. A route gets an entry when a screen needs it.
abstract final class ApiPaths {
  /// The two probes that hang off the base URL rather than `/v1`. No screen
  /// calls them — they are how a person checks the API is up (docs/RODANDO.md),
  /// and they keep the contract test honest about the unversioned prefix.
  static String get healthz => '${AppConfig.apiBaseUrl}/healthz';
  static String get readyz => '${AppConfig.apiBaseUrl}/readyz';

  static const authRegister = '/auth/register';
  static const authLogin = '/auth/login';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';
  static const passwordResetRequest = '/auth/password-reset/request';
  static const passwordResetConfirm = '/auth/password-reset/confirm';

  static bool isAuthPath(String path) => path.contains('/auth/');

  static const me = '/me';

  static const vehicles = '/vehicles';

  static String vehicle(String id) => '/vehicles/$id';

  static String vehicleOdometer(String id) => '/vehicles/$id/odometer';

  static String odometer(String id) => '/odometer/$id';

  /// The vehicle catalogue — the progressive picker on the registration form.
  ///
  /// Read-only: the app never writes to it. The server mirrors the source into
  /// its own database, so these are ordinary reads and not a proxy to a third
  /// party.
  static const vehicleBrands = '/vehicle-brands';

  static String vehicleBrandModels(String id) => '/vehicle-brands/$id/models';

  static String vehicleModelYears(String id) => '/vehicle-models/$id/years';

  static String vehicleModelYear(String id) => '/vehicle-model-years/$id';

  static const maintenanceItems = '/maintenance-items';

  static String vehicleMaintenancePlans(String id) =>
      '/vehicles/$id/maintenance-plans';

  static String maintenancePlan(String id) => '/maintenance-plans/$id';

  /// What the vehicle needs and what is still unknown about it. The app reads
  /// it and posts answers back; it never decides applicability itself.
  static String vehicleMaintenanceProfile(String id) =>
      '/vehicles/$id/maintenance-profile';

  static String vehicleMaintenanceProfileAnswers(String id) =>
      '/vehicles/$id/maintenance-profile/answers';

  static String vehicleMaintenanceRecords(String id) =>
      '/vehicles/$id/maintenance-records';

  static String maintenanceRecord(String id) => '/maintenance-records/$id';

  static String vehicleObligations(String id) => '/vehicles/$id/obligations';

  static String obligation(String id) => '/obligations/$id';

  static String vehicleSeguros(String id) => '/vehicles/$id/seguros';

  static String seguro(String id) => '/seguros/$id';

  static String vehicleDashboard(String id) => '/vehicles/$id/dashboard';

  static String vehicleTimeline(String id) => '/vehicles/$id/timeline';
}
