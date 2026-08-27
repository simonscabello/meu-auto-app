import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'api_error_code.dart';

final class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    this.fields = const {},
    this.details = const {},
    this.statusCode,
    this.requestId,
  });

  const ApiFailure.semConexao()
    : code = ApiErrorCode.semConexao,
      message =
          'O Meu Auto precisa de internet para funcionar. Conecte-se e tente de novo.',
      fields = const {},
      details = const {},
      statusCode = null,
      requestId = null;

  const ApiFailure.tempoEsgotado()
    : code = ApiErrorCode.tempoEsgotado,
      message = 'O servidor demorou a responder. Tente de novo.',
      fields = const {},
      details = const {},
      statusCode = null,
      requestId = null;

  const ApiFailure.respostaInesperada({this.statusCode})
    : code = ApiErrorCode.desconhecido,
      message = 'Algo deu errado. Tente novamente.',
      fields = const {},
      details = const {},
      requestId = null;

  final ApiErrorCode code;
  final String message;
  final Map<String, String> fields;
  final Map<String, dynamic> details;
  final int? statusCode;
  final String? requestId;

  factory ApiFailure.fromDioException(DioException err) {
    final existing = err.error;
    if (existing is ApiFailure) {
      return existing;
    }

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiFailure.tempoEsgotado();
      case DioExceptionType.connectionError:
        return const ApiFailure.semConexao();
      case DioExceptionType.badResponse:
        return ApiFailure._fromResponse(err.response);
      case DioExceptionType.unknown:
        if (err.error is SocketException) {
          return const ApiFailure.semConexao();
        }
        if (err.response != null) {
          return ApiFailure._fromResponse(err.response);
        }
        return const ApiFailure.respostaInesperada();
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return const ApiFailure.respostaInesperada();
    }
  }

  factory ApiFailure._fromResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    final envelope = _readEnvelope(response?.data);
    if (envelope == null) {
      return ApiFailure.respostaInesperada(statusCode: statusCode);
    }

    final code = ApiErrorCode.fromWire(envelope.code);
    final requestId = code == ApiErrorCode.internal
        ? envelope.details['request_id']?.toString()
        : null;

    return ApiFailure(
      code: code,
      message: envelope.message,
      fields: _fieldsOf(envelope.details),
      details: envelope.details,
      statusCode: statusCode,
      requestId: requestId,
    );
  }

  @override
  String toString() => 'ApiFailure($code: $message)';
}

({String code, String message, Map<String, dynamic> details})? _readEnvelope(
  dynamic data,
) {
  var payload = data;
  if (payload is String) {
    if (payload.isEmpty) {
      return null;
    }
    try {
      payload = jsonDecode(payload);
    } catch (_) {
      return null;
    }
  }
  if (payload is! Map) {
    return null;
  }
  final error = payload['error'];
  if (error is! Map) {
    return null;
  }
  final code = error['code'];
  final message = error['message'];
  if (code is! String || message is! String) {
    return null;
  }
  final rawDetails = error['details'];
  final details = rawDetails is Map
      ? Map<String, dynamic>.from(rawDetails)
      : <String, dynamic>{};
  return (code: code, message: message, details: details);
}

Map<String, String> _fieldsOf(Map<String, dynamic> details) {
  final raw = details['fields'];
  if (raw is! Map) {
    return const {};
  }
  return {
    for (final entry in raw.entries)
      entry.key.toString(): entry.value.toString(),
  };
}
