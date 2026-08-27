import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/config/app_config.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/core/session/session_tokens.dart';
import 'package:meu_auto/core/session/token_storage.dart';

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
    ),
  );
  final manager = SessionManager(
    storage: ref.watch(tokenStorageProvider),
    refreshDio: refreshDio,
  );
  ref.onDispose(() {
    manager.dispose();
    refreshDio.close(force: true);
  });
  return manager;
});

final class SessionManager {
  SessionManager({
    required this.storage,
    required this.refreshDio,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _proactiveWindow = Duration(seconds: 60);

  final TokenStorage storage;
  final Dio refreshDio;
  final DateTime Function() _now;

  final _sessionEnded = StreamController<void>.broadcast();
  Future<bool>? _inFlightRefresh;
  bool _ended = false;

  Stream<void> get sessionEnded => _sessionEnded.stream;

  Future<void> save(SessionTokens tokens) async {
    _ended = false;
    await storage.save(tokens);
  }

  Future<void> clear() async {
    _ended = true;
    await storage.clear();
  }

  Future<String?> peekAccessToken() async {
    final tokens = await storage.read();
    return tokens?.accessToken;
  }

  Future<String?> peekRefreshToken() async {
    final tokens = await storage.read();
    return tokens?.refreshToken;
  }

  Future<SessionTokens?> readTokens() => storage.read();

  Future<String?> validAccessToken() async {
    final tokens = await storage.read();
    if (tokens == null) {
      return null;
    }
    if (!tokens.isAccessExpiringWithin(_proactiveWindow, now: _now())) {
      return tokens.accessToken;
    }
    final renewed = await refresh();
    if (renewed) {
      return peekAccessToken();
    }
    // The proactive renewal did not go through. When the token on disk has not
    // actually expired yet, send it anyway: the 60s window is a safety margin,
    // not a deadline, and a token that still works beats no token at all.
    final current = await storage.read();
    if (current == null ||
        current.isAccessExpiringWithin(Duration.zero, now: _now())) {
      return null;
    }
    return current.accessToken;
  }

  Future<bool> refresh() {
    final inFlight = _inFlightRefresh;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _refreshOnce().whenComplete(() {
      _inFlightRefresh = null;
    });
    _inFlightRefresh = future;
    return future;
  }

  Future<bool> _refreshOnce() async {
    final tokens = await storage.read();
    if (tokens == null) {
      await _endSession();
      return false;
    }

    final Response<dynamic> response;
    try {
      response = await refreshDio.post<dynamic>(
        ApiPaths.authRefresh,
        data: {'refresh_token': tokens.refreshToken},
      );
    } on DioException catch (error) {
      if (_isServerRejection(error)) {
        // The server looked at the token and said no. It is dead, and keeping
        // it would only produce the same answer.
        await _endSession();
        return false;
      }
      // No answer came back — dropped signal, timeout, server down. The stored
      // refresh token was never spent and is still valid, so it stays. Wiping
      // it here would log the owner out for being in a parking garage, and
      // they would then need a password they may not have on them.
      return false;
    } on Object {
      return false;
    }

    // Past this point the server answered, which means it ALREADY rotated the
    // token we sent. Whatever is still on disk is revoked, so any failure from
    // here has to end the session: presenting that token again would be read as
    // reuse and would kill every session the user has.
    try {
      final data = response.data;
      if (data is! Map) {
        await _endSession();
        return false;
      }
      final next = SessionTokens.fromJson(Map<String, dynamic>.from(data));
      await storage.save(next);
      _ended = false;
      return true;
    } on Object {
      await _endSession();
      return false;
    }
  }

  /// True when the server actually answered and rejected the token, as opposed
  /// to the request never arriving. 5xx is the server being broken, not the
  /// token being invalid, so it is not a rejection.
  static bool _isServerRejection(DioException error) {
    final status = error.response?.statusCode;
    return status != null && status >= 400 && status < 500;
  }

  Future<void> _endSession() async {
    final shouldEmit = !_ended;
    _ended = true;
    await storage.clear();
    if (shouldEmit && !_sessionEnded.isClosed) {
      _sessionEnded.add(null);
    }
  }

  void dispose() {
    _sessionEnded.close();
  }
}
