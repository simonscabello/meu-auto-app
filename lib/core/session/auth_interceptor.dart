import 'package:dio/dio.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/core/session/session_manager.dart';

final class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.session, required this.dio});

  static const _retriedKey = 'auth_retried';

  final SessionManager session;
  final Dio dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (!ApiPaths.isAuthPath(options.path)) {
        final token = await session.validAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
      handler.next(options);
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        options.extra[_retriedKey] == true ||
        ApiPaths.isAuthPath(options.path)) {
      handler.next(err);
      return;
    }

    final sent = _bearer(options);
    final latest = await session.peekAccessToken();
    if (latest != null && latest != sent) {
      await _retry(options, latest, handler);
      return;
    }

    final renewed = await session.refresh();
    if (!renewed) {
      handler.next(err);
      return;
    }

    final token = await session.peekAccessToken();
    if (token == null) {
      handler.next(err);
      return;
    }
    await _retry(options, token, handler);
  }

  Future<void> _retry(
    RequestOptions options,
    String token,
    ErrorInterceptorHandler handler,
  ) async {
    options.extra[_retriedKey] = true;
    options.headers['Authorization'] = 'Bearer $token';
    try {
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (error) {
      handler.next(error);
    }
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
}
