import 'package:meu_auto/core/router/app_routes.dart';

/// Token carried by the password-reset deep link, or null when absent.
String? passwordResetTokenOf(Uri uri) {
  final token = uri.queryParameters['token']?.trim();
  if (token == null || token.isEmpty) {
    return null;
  }
  return token;
}

/// Maps `meuauto://redefinir-senha?token=` onto the in-app path.
///
/// Flutter delivers that custom-scheme URI with host `redefinir-senha` and an
/// empty path, which go_router would otherwise match as `/`. Returns null when
/// the URI is already the canonical `/redefinir-senha`.
String? rewritePasswordResetDeepLink(Uri uri) {
  if (uri.host != 'redefinir-senha') {
    return null;
  }
  final token = passwordResetTokenOf(uri);
  if (token == null) {
    return AppRoutes.passwordResetConfirm;
  }
  return Uri(
    path: AppRoutes.passwordResetConfirm,
    queryParameters: {'token': token},
  ).toString();
}
