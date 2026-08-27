import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/config/app_config.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_paths.dart';

void main() {
  test(
    'GET returns the JSON object and uses AppConfig base URL and timeouts',
    () async {
      RequestOptions? captured;
      final client = ApiClient(
        adapter: _FakeAdapter((options) async {
          captured = options;
          return _json(200, {'ok': true});
        }),
        logPrint: (_) {},
      );
      addTearDown(client.close);

      final body = await client.get('/ping');

      expect(body, {'ok': true});
      expect(captured!.uri.toString(), '${AppConfig.apiUrl}/ping');
      expect(captured!.connectTimeout, AppConfig.connectTimeout);
      expect(captured!.receiveTimeout, AppConfig.receiveTimeout);
      expect(
        captured!.headers[Headers.contentTypeHeader],
        Headers.jsonContentType,
      );
    },
  );

  test('paginationQuery emits limit and cursor only when present', () {
    final client = ApiClient(
      adapter: _FakeAdapter((_) async => _json(200, {})),
      logPrint: (_) {},
    );
    addTearDown(client.close);

    expect(client.paginationQuery(), isEmpty);
    expect(client.paginationQuery(limit: 20), {'limit': 20});
    expect(client.paginationQuery(limit: 20, cursor: 'abc'), {
      'limit': 20,
      'cursor': 'abc',
    });
  });

  test('422 validation_failed fills fields with the same keys', () async {
    final client = _clientReturning(422, {
      'error': {
        'code': 'validation_failed',
        'message': 'Não foi possível criar a conta.',
        'details': {
          'fields': {
            'email': 'Informe um e-mail válido.',
            'password': 'A senha deve ter pelo menos 8 caracteres.',
          },
        },
      },
    });

    final failure = await _expectFailure(
      client.post('/auth/register', body: {}),
    );
    expect(failure.code, ApiErrorCode.validationFailed);
    expect(failure.message, 'Não foi possível criar a conta.');
    expect(failure.statusCode, 422);
    expect(failure.fields, {
      'email': 'Informe um e-mail válido.',
      'password': 'A senha deve ter pelo menos 8 caracteres.',
    });
  });

  test('422 odometer_rollback keeps neighbour details', () async {
    final client = _clientReturning(422, {
      'error': {
        'code': 'odometer_rollback',
        'message':
            'A quilometragem informada é menor que a do registro anterior.',
        'details': {
          'previous_mileage_km': 98200,
          'previous_occurred_on': '2026-08-10',
          'submitted_mileage_km': 90000,
          'hint':
              'Se o painel foi trocado ou o valor anterior estava errado, reenvie com source "correction".',
        },
      },
    });

    final failure = await _expectFailure(
      client.post(ApiPaths.vehicleOdometer('v1'), body: {'mileage_km': 90000}),
    );
    expect(failure.code, ApiErrorCode.odometerRollback);
    expect(failure.details['previous_mileage_km'], 98200);
    expect(failure.fields, isEmpty);
  });

  test('404 uses notFound and the server message', () async {
    final client = _clientReturning(404, {
      'error': {'code': 'not_found', 'message': 'Veículo não encontrado.'},
    });

    final failure = await _expectFailure(
      client.get(ApiPaths.vehicle('missing')),
    );
    expect(failure.code, ApiErrorCode.notFound);
    expect(failure.message, 'Veículo não encontrado.');
    expect(failure.statusCode, 404);
    expect(failure.details, isEmpty);
  });

  test('500 internal captures request_id', () async {
    final client = _clientReturning(500, {
      'error': {
        'code': 'internal',
        'message': 'Ocorreu um erro inesperado. Tente novamente.',
        'details': {'request_id': 'req-123'},
      },
    });

    final failure = await _expectFailure(client.get('/boom'));
    expect(failure.code, ApiErrorCode.internal);
    expect(failure.requestId, 'req-123');
    expect(failure.message, 'Ocorreu um erro inesperado. Tente novamente.');
  });

  test(
    'non-envelope body becomes desconhecido without a parse exception',
    () async {
      final client = ApiClient(
        adapter: _FakeAdapter(
          (_) async => ResponseBody.fromString(
            '<html>bad gateway</html>',
            502,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            },
          ),
        ),
        logPrint: (_) {},
      );
      addTearDown(client.close);

      final failure = await _expectFailure(client.get('/proxy'));
      expect(failure.code, ApiErrorCode.desconhecido);
      expect(failure.message, 'Algo deu errado. Tente novamente.');
      expect(failure.statusCode, 502);
    },
  );

  test('invented error code becomes desconhecido without throwing', () async {
    final client = _clientReturning(418, {
      'error': {'code': 'algo_novo', 'message': 'Uma falha nova do servidor.'},
    });

    final failure = await _expectFailure(client.get('/novo'));
    expect(failure.code, ApiErrorCode.desconhecido);
    expect(failure.message, 'Uma falha nova do servidor.');
    expect(failure.statusCode, 418);
  });

  test('connection error becomes semConexao with the local message', () async {
    final client = ApiClient(
      adapter: _FakeAdapter(
        (_) async => throw const SocketException('Failed host lookup'),
      ),
      logPrint: (_) {},
    );
    addTearDown(client.close);

    final failure = await _expectFailure(client.get('/anywhere'));
    expect(failure.code, ApiErrorCode.semConexao);
    expect(
      failure.message,
      'O Meu Auto precisa de internet para funcionar. Conecte-se e tente de novo.',
    );
    expect(failure.statusCode, isNull);
  });

  test('timeouts become tempoEsgotado', () async {
    final client = ApiClient(
      adapter: _FakeAdapter(
        (options) async => throw DioException.connectionTimeout(
          timeout: AppConfig.connectTimeout,
          requestOptions: options,
        ),
      ),
      logPrint: (_) {},
    );
    addTearDown(client.close);

    final failure = await _expectFailure(client.get('/slow'));
    expect(failure.code, ApiErrorCode.tempoEsgotado);
    expect(failure.message, 'O servidor demorou a responder. Tente de novo.');
    expect(failure.statusCode, isNull);
  });
}

ApiClient _clientReturning(int status, Map<String, dynamic> body) {
  final client = ApiClient(
    adapter: _FakeAdapter((_) async => _json(status, body)),
    logPrint: (_) {},
  );
  addTearDown(client.close);
  return client;
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

ResponseBody _json(int status, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options) _onFetch;

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
    return _onFetch(options);
  }
}
