import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/config/app_config.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/error_interceptor.dart';
import 'package:meu_auto/core/network/logging_interceptor.dart';
import 'package:meu_auto/core/session/auth_interceptor.dart';
import 'package:meu_auto/core/session/session_manager.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(sessionManager: ref.watch(sessionManagerProvider));
  ref.onDispose(client.close);
  return client;
});

final class ApiClient {
  ApiClient({
    HttpClientAdapter? adapter,
    SessionManager? sessionManager,
    void Function(String message)? logPrint,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: AppConfig.apiUrl,
           connectTimeout: AppConfig.connectTimeout,
           receiveTimeout: AppConfig.receiveTimeout,
           sendTimeout: AppConfig.receiveTimeout,
           contentType: Headers.jsonContentType,
         ),
       ) {
    if (adapter != null) {
      _dio.httpClientAdapter = adapter;
    }
    if (sessionManager != null) {
      _dio.interceptors.add(
        AuthInterceptor(session: sessionManager, dio: _dio),
      );
    }
    if (kDebugMode) {
      _dio.interceptors.add(LoggingInterceptor(logPrint: logPrint));
    }
    _dio.interceptors.add(const ErrorInterceptor());
  }

  final Dio _dio;

  Map<String, dynamic> paginationQuery({int? limit, String? cursor}) {
    return {'limit': ?limit, 'cursor': ?cursor};
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _send('GET', path, query: query);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) {
    return _send('POST', path, body: body, query: query);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) {
    return _send('PATCH', path, body: body, query: query);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) {
    return _send('DELETE', path, body: body, query: query);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      return _asMap(response.data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data == null || data == '') {
      return {};
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiFailure.respostaInesperada();
  }

  ApiFailure _unwrap(DioException exception) {
    final error = exception.error;
    if (error is ApiFailure) {
      return error;
    }
    return ApiFailure.fromDioException(exception);
  }

  void close() => _dio.close(force: true);
}
