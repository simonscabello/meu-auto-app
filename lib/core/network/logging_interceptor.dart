import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

final class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({void Function(String message)? logPrint})
    : _logPrint = logPrint ?? debugPrint;

  static const _startedAtKey = 'logging_started_at';
  static const _redacted = '[redacted]';
  static const _sensitiveKeys = {
    'password',
    'access_token',
    'refresh_token',
    'token',
  };

  final void Function(String message) _logPrint;

  /// A debug logger must never be the reason a request fails. Anything thrown
  /// while formatting — an unencodable body, a surprising header type — is
  /// swallowed here, because losing a log line is nothing and losing the
  /// request is a bug that only reproduces in debug builds.
  void _safely(void Function() log) {
    if (!kDebugMode) {
      return;
    }
    try {
      log();
    } on Object {
      _logPrint('[log falhou]');
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now();
    _safely(() => _logRequest(options));
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _safely(
      () => _logOutcome(
        response.requestOptions,
        status: response.statusCode,
        body: response.data,
      ),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _safely(
      () => _logOutcome(
        err.requestOptions,
        status: err.response?.statusCode,
        body: err.response?.data,
      ),
    );
    handler.next(err);
  }

  void _logRequest(RequestOptions options) {
    _logPrint('${options.method} ${options.path}');
    _redactedHeaders(options.headers).forEach((key, value) {
      _logPrint('$key: $value');
    });
    if (options.data != null) {
      _logPrint('body: ${_format(_redact(options.data))}');
    }
  }

  void _logOutcome(
    RequestOptions options, {
    required int? status,
    required Object? body,
  }) {
    final started = options.extra[_startedAtKey];
    final elapsed = started is DateTime
        ? DateTime.now().difference(started).inMilliseconds
        : 0;
    _logPrint('$status ${elapsed}ms');
    if (body != null) {
      _logPrint('body: ${_format(_redact(body))}');
    }
  }

  Map<String, Object?> _redactedHeaders(Map<String, dynamic> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: entry.key.toLowerCase() == 'authorization'
            ? _redacted
            : entry.value,
    };
  }

  Object? _redact(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key: _sensitiveKeys.contains(entry.key)
              ? _redacted
              : _redact(entry.value),
      };
    }
    if (value is List) {
      return [for (final item in value) _redact(item)];
    }
    return value;
  }

  String _format(Object? value) {
    if (value is Map || value is List) {
      return jsonEncode(value);
    }
    return value.toString();
  }
}
