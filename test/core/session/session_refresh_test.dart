import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/config/app_config.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/core/session/session_manager.dart';
import 'package:meu_auto/core/session/session_tokens.dart';
import 'package:meu_auto/core/session/token_storage.dart';

void main() {
  late TokenStorage storage;
  late _CountingAdapter adapter;
  late SessionManager session;
  late ApiClient client;
  late List<String> logs;

  setUp(() {
    storage = TokenStorage.memory();
    adapter = _CountingAdapter();
    session = SessionManager(
      storage: storage,
      refreshDio: _refreshDio(adapter),
    );
    logs = <String>[];
    client = ApiClient(
      adapter: adapter,
      sessionManager: session,
      logPrint: logs.add,
    );
  });

  tearDown(() {
    client.close();
    session.dispose();
  });

  test(
    'five simultaneous 401s call /auth/refresh exactly once and retry all five with the new token',
    () async {
      await storage.save(_tokens(access: 'old-access', refresh: 'old-refresh'));
      adapter
        ..oldAccessToken = 'old-access'
        ..newAccessToken = 'new-access'
        ..newRefreshToken = 'new-refresh';

      final paths = [
        ApiPaths.vehicleDashboard('v1'),
        ApiPaths.vehicleMaintenancePlans('v1'),
        ApiPaths.vehicleTimeline('v1'),
        ApiPaths.vehicles,
        ApiPaths.me,
      ];

      final bodies = await Future.wait(paths.map(client.get));

      expect(adapter.refreshCalls, 1);
      expect(adapter.unauthorizedProtectedCalls, 5);
      expect(adapter.retriedWithNewToken, 5);
      expect(bodies, everyElement({'ok': true}));
      expect((await storage.read())!.accessToken, 'new-access');
      expect((await storage.read())!.refreshToken, 'new-refresh');
      final joined = logs.join('\n');
      expect(joined, isNot(contains('old-access')));
      expect(joined, isNot(contains('new-access')));
      expect(joined, isNot(contains('old-refresh')));
      expect(joined, isNot(contains('new-refresh')));
    },
  );

  test(
    'proactive refresh renews an access token expiring in 30s before the request, without a 401',
    () async {
      await storage.save(
        _tokens(
          access: 'old-access',
          refresh: 'old-refresh',
          accessExpiresIn: const Duration(seconds: 30),
        ),
      );
      adapter
        ..oldAccessToken = 'old-access'
        ..newAccessToken = 'new-access'
        ..newRefreshToken = 'new-refresh'
        ..failIfOldAccessTokenHitsProtected = true;

      final body = await client.get(ApiPaths.vehicleDashboard('v1'));

      expect(body, {'ok': true});
      expect(adapter.refreshCalls, 1);
      expect(adapter.unauthorizedProtectedCalls, 0);
      expect(adapter.protectedCallsWithNewToken, 1);
      expect((await storage.read())!.accessToken, 'new-access');
    },
  );

  test(
    'failed refresh clears storage and emits session ended exactly once',
    () async {
      await storage.save(
        _tokens(access: 'old-access', refresh: 'dead-refresh'),
      );
      adapter
        ..oldAccessToken = 'old-access'
        ..refreshStatus = 401;

      final ended = <void>[];
      final sub = session.sessionEnded.listen(ended.add);

      final paths = [
        ApiPaths.vehicleDashboard('v1'),
        ApiPaths.vehicleMaintenancePlans('v1'),
        ApiPaths.vehicleTimeline('v1'),
        ApiPaths.vehicles,
        ApiPaths.me,
      ];
      final failures = await Future.wait(
        paths.map((path) => _expectFailure(client.get(path))),
      );

      await pumpEventQueue();
      await sub.cancel();

      expect(adapter.refreshCalls, 1);
      expect(ended, hasLength(1));
      expect(await storage.read(), isNull);
      expect(
        failures.every((f) => f.code == ApiErrorCode.unauthorized),
        isTrue,
      );
    },
  );

  test('a 401 on /auth/login does not trigger refresh', () async {
    adapter.loginStatus = 401;

    final failure = await _expectFailure(
      client.post(
        ApiPaths.authLogin,
        body: {'email': 'a@b.c', 'password': 'x'},
      ),
    );

    expect(failure.code, ApiErrorCode.unauthorized);
    expect(adapter.refreshCalls, 0);
  });

  test('the same request is not retried more than once', () async {
    await storage.save(_tokens(access: 'old-access', refresh: 'old-refresh'));
    adapter
      ..oldAccessToken = 'old-access'
      ..newAccessToken = 'new-access'
      ..newRefreshToken = 'new-refresh'
      ..protectedAlwaysUnauthorized = true;

    final failure = await _expectFailure(
      client.get(ApiPaths.vehicleDashboard('v1')),
    );

    expect(failure.code, ApiErrorCode.unauthorized);
    expect(adapter.refreshCalls, 1);
    expect(adapter.protectedCalls, 2);
  });

  test(
    'an access token already expired on disk is renewed before the first use',
    () async {
      await storage.save(
        _tokens(
          access: 'old-access',
          refresh: 'old-refresh',
          accessExpiresIn: const Duration(seconds: -5),
        ),
      );
      adapter
        ..storage = storage
        ..oldAccessToken = 'old-access'
        ..newAccessToken = 'new-access'
        ..newRefreshToken = 'new-refresh'
        ..failIfOldAccessTokenHitsProtected = true;

      final body = await client.get(ApiPaths.vehicleDashboard('v1'));

      expect(body, {'ok': true});
      expect(adapter.refreshCalls, 1);
      expect(adapter.unauthorizedProtectedCalls, 0);
      expect(adapter.protectedCallsWithNewToken, 1);
      expect((await storage.read())!.accessToken, 'new-access');
    },
  );

  test('failed renewal of an expired token logs out exactly once', () async {
    await storage.save(
      _tokens(
        access: 'old-access',
        refresh: 'dead-refresh',
        accessExpiresIn: const Duration(seconds: -5),
      ),
    );
    adapter
      ..oldAccessToken = 'old-access'
      ..refreshStatus = 401;

    final ended = <void>[];
    final sub = session.sessionEnded.listen(ended.add);

    final failure = await _expectFailure(
      client.get(ApiPaths.vehicleDashboard('v1')),
    );

    await pumpEventQueue();

    expect(failure.code, ApiErrorCode.unauthorized);
    expect(ended, hasLength(1));
    expect(await storage.read(), isNull);

    final second = await _expectFailure(
      client.get(ApiPaths.vehicleDashboard('v1')),
    );
    await pumpEventQueue();
    await sub.cancel();

    expect(second.code, ApiErrorCode.unauthorized);
    expect(ended, hasLength(1));
  });

  test(
    'the new token is persisted before any retried request leaves',
    () async {
      await storage.save(_tokens(access: 'old-access', refresh: 'old-refresh'));
      adapter
        ..storage = storage
        ..oldAccessToken = 'old-access'
        ..newAccessToken = 'new-access'
        ..newRefreshToken = 'new-refresh';

      await client.get(ApiPaths.vehicleDashboard('v1'));

      expect(adapter.refreshCalls, 1);
      expect(adapter.retriedWithNewToken, 1);
      expect(adapter.newTokenWasOnDiskWhenSent, isTrue);
      expect((await storage.read())!.accessToken, 'new-access');
    },
  );
}

SessionTokens _tokens({
  required String access,
  required String refresh,
  Duration accessExpiresIn = const Duration(minutes: 10),
}) {
  final now = DateTime.now();
  return SessionTokens(
    accessToken: access,
    expiresAt: now.add(accessExpiresIn),
    refreshToken: refresh,
    refreshExpiresAt: now.add(const Duration(days: 30)),
  );
}

Dio _refreshDio(HttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      contentType: Headers.jsonContentType,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

Future<ApiFailure> _expectFailure(Future<Object?> future) async {
  try {
    await future;
    fail('expected ApiFailure');
  } on DioException {
    fail('DioException escaped lib/core/network');
  } on ApiFailure catch (failure) {
    return failure;
  }
}

final class _CountingAdapter implements HttpClientAdapter {
  String oldAccessToken = 'old-access';
  String newAccessToken = 'new-access';
  String newRefreshToken = 'new-refresh';
  int refreshStatus = 200;
  int loginStatus = 200;
  bool failIfOldAccessTokenHitsProtected = false;
  bool protectedAlwaysUnauthorized = false;

  int refreshCalls = 0;
  int unauthorizedProtectedCalls = 0;
  int protectedCallsWithNewToken = 0;
  int retriedWithNewToken = 0;
  int protectedCalls = 0;
  TokenStorage? storage;
  bool? newTokenWasOnDiskWhenSent;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await requestStream.drain<void>();
    }

    if (_isRefresh(options)) {
      refreshCalls++;
      // Yield so every concurrent 401 can join the in-flight refresh.
      await Future<void>.delayed(Duration.zero);
      if (refreshStatus != 200) {
        return _json(refreshStatus, {
          'error': {
            'code': 'unauthorized',
            'message': 'Sessão inválida ou expirada. Entre novamente.',
          },
        });
      }
      return _json(200, _sessionBody(newAccessToken, newRefreshToken));
    }

    if (options.path == ApiPaths.authLogin) {
      return _json(loginStatus, {
        'error': {
          'code': 'unauthorized',
          'message': 'E-mail ou senha incorretos.',
        },
      });
    }

    protectedCalls++;
    final sent = _bearer(options);
    if (protectedAlwaysUnauthorized) {
      if (sent == oldAccessToken) {
        unauthorizedProtectedCalls++;
        return _unauthorized();
      }
      return _unauthorized();
    }

    if (sent == newAccessToken) {
      protectedCallsWithNewToken++;
      retriedWithNewToken++;
      final stored = await storage?.read();
      newTokenWasOnDiskWhenSent = stored?.accessToken == newAccessToken;
      return _json(200, {'ok': true});
    }

    if (failIfOldAccessTokenHitsProtected && sent == oldAccessToken) {
      fail('protected request went out with the expiring access token');
    }

    unauthorizedProtectedCalls++;
    return _unauthorized();
  }

  bool _isRefresh(RequestOptions options) {
    return options.path.contains('/auth/refresh') ||
        options.uri.path.contains('/auth/refresh');
  }

  String? _bearer(RequestOptions options) {
    final raw =
        options.headers['Authorization'] ?? options.headers['authorization'];
    if (raw is! String) {
      return null;
    }
    const prefix = 'Bearer ';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length);
    }
    return raw;
  }

  ResponseBody _unauthorized() {
    return _json(401, {
      'error': {
        'code': 'unauthorized',
        'message': 'Sessão inválida ou expirada. Entre novamente.',
      },
    });
  }
}

Map<String, dynamic> _sessionBody(String access, String refresh) {
  final now = DateTime.now().toUtc();
  return {
    'user': {
      'id': '11111111-1111-1111-1111-111111111111',
      'name': 'Ana',
      'email': 'ana@example.com',
      'created_at': '2026-01-15T12:00:00Z',
    },
    'token_type': 'Bearer',
    'access_token': access,
    'expires_at': now.add(const Duration(minutes: 15)).toIso8601String(),
    'refresh_token': refresh,
    'refresh_expires_at': now.add(const Duration(days: 30)).toIso8601String(),
  };
}

ResponseBody _json(int status, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
