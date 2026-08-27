import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/session/session_manager.dart';
import 'package:meu_auto/core/session/session_tokens.dart';
import 'package:meu_auto/features/auth/data/auth_repository.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/session.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthStatus>(AuthController.new);

class AuthController extends AsyncNotifier<AuthStatus> {
  @override
  Future<AuthStatus> build() {
    final session = ref.watch(sessionManagerProvider);
    var closed = false;
    final subscription = session.sessionEnded.listen((_) {
      if (closed) {
        return;
      }
      state = const AsyncData(AuthLoggedOut());
    });
    ref.onDispose(() {
      closed = true;
      subscription.cancel();
    });
    return bootstrap();
  }

  Future<AuthStatus> bootstrap() async {
    final session = ref.read(sessionManagerProvider);
    SessionTokens? tokens;
    try {
      tokens = await session.readTokens();
    } on Object {
      await session.clear();
      return const AuthLoggedOut();
    }
    if (tokens == null) {
      return const AuthLoggedOut();
    }

    try {
      final user = await ref.read(authRepositoryProvider).me();
      return AuthLoggedIn(user);
    } on ApiFailure catch (failure) {
      if (failure.code == ApiErrorCode.unauthorized) {
        await session.clear();
        return const AuthLoggedOut();
      }
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .register(name: name, email: email, password: password);
    await _becomeLoggedIn(session);
  }

  Future<void> login({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    await _becomeLoggedIn(session);
  }

  Future<void> logout() async {
    final session = ref.read(sessionManagerProvider);
    final refreshToken = await session.peekRefreshToken();
    if (refreshToken != null) {
      try {
        await ref.read(authRepositoryProvider).logout(refreshToken);
      } on Object {
        // The UI always signs out, even when the server call fails.
      }
    }
    await _endLocalSession();
  }

  Future<void> updateName(String name) async {
    final user = await ref.read(authRepositoryProvider).updateMe(name: name);
    state = AsyncData(AuthLoggedIn(user));
  }

  Future<void> deleteAccount({required String password}) async {
    await ref.read(authRepositoryProvider).deleteMe(password: password);
  }

  /// Drops tokens locally without calling logout. Used after a password reset,
  /// which already revoked every session on the server.
  Future<void> clearLocalSession() => _endLocalSession();

  Future<void> _endLocalSession() async {
    await ref.read(sessionManagerProvider).clear();
    state = const AsyncData(AuthLoggedOut());
  }

  Future<void> _becomeLoggedIn(Session session) async {
    await ref.read(sessionManagerProvider).save(session.tokens);
    state = AsyncData(AuthLoggedIn(session.user));
  }
}
