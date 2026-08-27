import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/config/app_config.dart';
import 'package:meu_auto/core/session/session_manager.dart';
import 'package:meu_auto/core/session/session_tokens.dart';
import 'package:meu_auto/core/session/token_storage.dart';

/// A refresh that never reaches the server must not cost the owner their
/// session.
///
/// The backend rotates refresh tokens, so the reflex is to treat every failed
/// refresh as a dead token and wipe storage. That is right when the server
/// answered and said no, and wrong when nothing came back at all: the stored
/// token was never spent. Getting this backwards logs someone out for opening
/// the app in a parking garage — and they then need a password they may not
/// have on them, over a connection they do not have either.
void main() {
  late TokenStorage storage;
  late _ScriptedRefreshAdapter adapter;
  late SessionManager session;
  late DateTime now;

  SessionTokens tokensExpiringIn(Duration remaining) {
    return SessionTokens(
      accessToken: 'stored-access',
      expiresAt: now.add(remaining),
      refreshToken: 'stored-refresh',
      refreshExpiresAt: now.add(const Duration(days: 30)),
    );
  }

  setUp(() {
    now = DateTime(2026, 8, 26, 10);
    storage = TokenStorage.memory();
    adapter = _ScriptedRefreshAdapter();
    session = SessionManager(
      storage: storage,
      refreshDio: Dio(BaseOptions(baseUrl: AppConfig.apiUrl))
        ..httpClientAdapter = adapter,
      now: () => now,
    );
  });

  tearDown(() => session.dispose());

  test('a refresh that never reaches the server keeps the tokens', () async {
    await storage.save(tokensExpiringIn(const Duration(seconds: -1)));
    adapter.outcome = _Outcome.offline;

    final ended = <void>[];
    final sub = session.sessionEnded.listen(ended.add);

    final renewed = await session.refresh();
    await pumpEventQueue();
    await sub.cancel();

    expect(renewed, isFalse, reason: 'the refresh did not succeed');
    expect(
      await storage.read(),
      isNotNull,
      reason: 'the refresh token was never spent, so it is still valid',
    );
    expect(ended, isEmpty, reason: 'this is not the end of the session');
  });

  test(
    'a 5xx keeps the tokens — the server is broken, not the token',
    () async {
      await storage.save(tokensExpiringIn(const Duration(seconds: -1)));
      adapter.outcome = _Outcome.serverError;

      final renewed = await session.refresh();

      expect(renewed, isFalse);
      expect(await storage.read(), isNotNull);
    },
  );

  test('a 401 clears the tokens — the server looked and said no', () async {
    await storage.save(tokensExpiringIn(const Duration(seconds: -1)));
    adapter.outcome = _Outcome.rejected;

    final ended = <void>[];
    final sub = session.sessionEnded.listen(ended.add);

    final renewed = await session.refresh();
    await pumpEventQueue();
    await sub.cancel();

    expect(renewed, isFalse);
    expect(await storage.read(), isNull);
    expect(ended, hasLength(1));
  });

  test('an answered refresh that cannot be read ends the session, because the '
      'server already rotated the token we sent', () async {
    await storage.save(tokensExpiringIn(const Duration(seconds: -1)));
    adapter.outcome = _Outcome.unreadableSuccess;

    final renewed = await session.refresh();

    expect(renewed, isFalse);
    expect(await storage.read(), isNull);
  });

  test('a failed proactive refresh still sends an access token that has not '
      'actually expired', () async {
    // Inside the 60s proactive window, so a renewal is attempted — but the
    // token itself is good for another 30 seconds.
    await storage.save(tokensExpiringIn(const Duration(seconds: 30)));
    adapter.outcome = _Outcome.offline;

    expect(await session.validAccessToken(), 'stored-access');
    expect(adapter.calls, 1, reason: 'the renewal was attempted');
  });

  test('a failed refresh on an expired token sends nothing', () async {
    await storage.save(tokensExpiringIn(const Duration(seconds: -1)));
    adapter.outcome = _Outcome.offline;

    expect(await session.validAccessToken(), isNull);
    expect(
      await storage.read(),
      isNotNull,
      reason: 'still no reason to throw the refresh token away',
    );
  });
}

enum _Outcome { offline, serverError, rejected, unreadableSuccess }

final class _ScriptedRefreshAdapter implements HttpClientAdapter {
  _Outcome outcome = _Outcome.offline;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    switch (outcome) {
      case _Outcome.offline:
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'sem rede',
        );
      case _Outcome.serverError:
        return _json(500, {
          'error': {'code': 'internal', 'message': 'Erro interno.'},
        });
      case _Outcome.rejected:
        return _json(401, {
          'error': {'code': 'unauthorized', 'message': 'Sessão inválida.'},
        });
      case _Outcome.unreadableSuccess:
        return _json(200, {'nao': 'e uma sessao'});
    }
  }

  @override
  void close({bool force = false}) {}
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
