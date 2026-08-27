import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';

/// [hasVehicles] is `null` while the list is unknown (still loading or failed
/// on first fetch). `false` means the account has none; `true` means at least one.
String? authRedirect({
  required AuthStatus status,
  required String location,
  bool? hasVehicles,
}) {
  // The e-mail deep link must open even with no session, during bootstrap,
  // and while the owner is already signed in.
  if (location == AppRoutes.passwordResetConfirm) {
    return null;
  }
  switch (status) {
    case AuthUnknown():
      if (location == AppRoutes.splash) {
        return null;
      }
      return AppRoutes.splash;
    case AuthLoggedOut():
      if (_isPublicAuthRoute(location)) {
        return null;
      }
      return AppRoutes.login;
    case AuthLoggedIn():
      return _loggedInRedirect(location: location, hasVehicles: hasVehicles);
  }
}

String? _loggedInRedirect({
  required String location,
  required bool? hasVehicles,
}) {
  if (hasVehicles == null) {
    if (location == AppRoutes.splash) {
      return null;
    }
    if (_isPublicAuthRoute(location)) {
      return AppRoutes.splash;
    }
    return null;
  }
  if (!hasVehicles) {
    if (location == AppRoutes.vehicleNew) {
      return null;
    }
    return AppRoutes.vehicleNew;
  }
  if (location == AppRoutes.splash || _isPublicAuthRoute(location)) {
    return AppRoutes.home;
  }
  return null;
}

bool _isPublicAuthRoute(String location) {
  return location == AppRoutes.login ||
      location == AppRoutes.register ||
      location == AppRoutes.passwordReset;
}
