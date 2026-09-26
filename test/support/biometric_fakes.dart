import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meu_auto/core/session/session_tokens.dart';
import 'package:meu_auto/features/auth/data/device_biometrics.dart';
import 'package:meu_auto/features/auth/domain/user.dart';

User testUser({String id = 'u1', String name = 'Ana'}) => User(
  id: id,
  name: name,
  email: '${name.toLowerCase()}@example.com',
  createdAt: DateTime(2026),
);

/// Tokens that stay valid for the whole test, so nothing tries to renew
/// them over the network.
SessionTokens testTokens({String refresh = 'stored-refresh'}) => SessionTokens(
  accessToken: 'access-$refresh',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  refreshToken: refresh,
  refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
);

/// The phone's sensor, scripted. [checks] answers the prompts in order and
/// then keeps answering with the last one.
final class FakeBiometrics implements DeviceBiometrics {
  FakeBiometrics({
    this.available = true,
    List<BiometricCheck> checks = const [BiometricCheck.confirmed],
  }) : _checks = [...checks];

  bool available;
  final List<BiometricCheck> _checks;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricCheck> confirm() async {
    prompts++;
    if (!available) return BiometricCheck.notConfirmed;
    return _checks.length > 1 ? _checks.removeAt(0) : _checks.single;
  }
}

enum MeAnswer { ok, offline, unauthorized }

/// The auth half of the API, scripted at the HTTP level (the repository is
/// a final class, and going through it keeps the parsing honest). Plug it
/// into `ApiClient(adapter: …)`; nothing reaches a network.
final class FakeAuthServer implements HttpClientAdapter {
  FakeAuthServer({User? me, User? signsIn})
    : me = me ?? testUser(),
      signsIn = signsIn ?? me ?? testUser();

  /// Who `/me` answers with. Changing it mid-test is how a stored session
  /// that belongs to someone else is simulated.
  User me;
  MeAnswer meAnswer = MeAnswer.ok;

  /// Who a sign-in or a registration creates a session for.
  User signsIn;

  int meCalls = 0;

  /// Refresh tokens presented to `/auth/logout`, in order.
  final revoked = <String>[];
  int _sessions = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final method = options.method;
    if (path.endsWith('/me') && method == 'GET') {
      meCalls++;
      switch (meAnswer) {
        case MeAnswer.offline:
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        case MeAnswer.unauthorized:
          return _json(401, {
            'error': {
              'code': 'unauthorized',
              'message': 'Sessão inválida ou expirada. Entre novamente.',
            },
          });
        case MeAnswer.ok:
          return _json(200, _user(me));
      }
    }
    if (path.endsWith('/auth/login') || path.endsWith('/auth/register')) {
      _sessions++;
      final now = DateTime.now().toUtc();
      return _json(200, {
        'access_token': 'new-access-$_sessions',
        'expires_at': now.add(const Duration(hours: 1)).toIso8601String(),
        'refresh_token': 'new-refresh-$_sessions',
        'refresh_expires_at': now
            .add(const Duration(days: 30))
            .toIso8601String(),
        'token_type': 'Bearer',
        'user': _user(signsIn),
      });
    }
    if (path.endsWith('/auth/logout')) {
      final body = options.data;
      if (body is Map) revoked.add(body['refresh_token'] as String);
      return ResponseBody.fromString('', 204);
    }
    if (path.endsWith('/me') && method == 'DELETE') {
      return ResponseBody.fromString('', 204);
    }
    return _json(404, {
      'error': {'code': 'not_found', 'message': 'Não encontrado.'},
    });
  }

  static Map<String, dynamic> _user(User user) => {
    'id': user.id,
    'name': user.name,
    'email': user.email,
    'created_at': '2026-01-15T12:00:00Z',
    'birth_date': null,
    'phone': null,
    'cnh_category': null,
    'cnh_expires_on': null,
    'photo_url': null,
  };

  static ResponseBody _json(int status, Map<String, dynamic> body) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
