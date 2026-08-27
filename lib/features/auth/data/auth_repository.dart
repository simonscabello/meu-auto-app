import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/auth/domain/session.dart';
import 'package:meu_auto/features/auth/domain/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(api: ref.watch(apiClientProvider));
});

final class AuthRepository {
  AuthRepository({required this.api});

  final ApiClient api;

  Future<Session> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final body = await api.post(
      ApiPaths.authRegister,
      body: {'name': name, 'email': email, 'password': password},
    );
    return Session.fromJson(body);
  }

  Future<Session> login({
    required String email,
    required String password,
  }) async {
    final body = await api.post(
      ApiPaths.authLogin,
      body: {'email': email, 'password': password},
    );
    return Session.fromJson(body);
  }

  Future<void> logout(String refreshToken) async {
    await api.post(ApiPaths.authLogout, body: {'refresh_token': refreshToken});
  }

  Future<User> me() async {
    final body = await api.get(ApiPaths.me);
    return User.fromJson(body);
  }

  Future<void> requestPasswordReset({required String email}) async {
    await api.post(ApiPaths.passwordResetRequest, body: {'email': email});
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String password,
  }) async {
    await api.post(
      ApiPaths.passwordResetConfirm,
      body: {'token': token, 'password': password},
    );
  }

  Future<User> updateMe({required String name}) async {
    final body = await api.patch(ApiPaths.me, body: {'name': name});
    return User.fromJson(body);
  }

  Future<void> deleteMe({required String password}) async {
    await api.delete(ApiPaths.me, body: {'password': password});
  }
}
