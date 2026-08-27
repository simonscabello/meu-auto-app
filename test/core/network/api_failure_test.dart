import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';

import '../../support/fixtures.dart';

void main() {
  test('local constructors carry the pt-BR copy and no status code', () {
    const offline = ApiFailure.semConexao();
    expect(offline.code, ApiErrorCode.semConexao);
    expect(
      offline.message,
      'O Meu Auto precisa de internet para funcionar. Conecte-se e tente de novo.',
    );
    expect(offline.statusCode, isNull);
    expect(offline.fields, isEmpty);

    const timeout = ApiFailure.tempoEsgotado();
    expect(timeout.code, ApiErrorCode.tempoEsgotado);
    expect(timeout.message, 'O servidor demorou a responder. Tente de novo.');
    expect(timeout.statusCode, isNull);

    const unexpected = ApiFailure.respostaInesperada(statusCode: 502);
    expect(unexpected.code, ApiErrorCode.desconhecido);
    expect(unexpected.message, 'Algo deu errado. Tente novamente.');
    expect(unexpected.statusCode, 502);
  });

  test('each contract code maps from an error envelope', () {
    const cases = <(String, int, ApiErrorCode)>[
      ('validation_failed', 422, ApiErrorCode.validationFailed),
      ('unauthorized', 401, ApiErrorCode.unauthorized),
      ('forbidden', 403, ApiErrorCode.forbidden),
      ('not_found', 404, ApiErrorCode.notFound),
      ('method_not_allowed', 405, ApiErrorCode.methodNotAllowed),
      ('conflict', 409, ApiErrorCode.conflict),
      ('odometer_rollback', 422, ApiErrorCode.odometerRollback),
      ('rate_limited', 429, ApiErrorCode.rateLimited),
      ('internal', 500, ApiErrorCode.internal),
    ];

    for (final (wire, status, expected) in cases) {
      final failure = _fromEnvelope(status, {
        'error': {'code': wire, 'message': 'mensagem do servidor.'},
      });
      expect(failure.code, expected, reason: wire);
      expect(failure.message, 'mensagem do servidor.');
      expect(failure.statusCode, status);
    }
  });

  test('an invented wire code becomes desconhecido without throwing', () {
    final failure = _fromEnvelope(418, {
      'error': {'code': 'algo_novo', 'message': 'Uma falha nova do servidor.'},
    });
    expect(failure.code, ApiErrorCode.desconhecido);
    expect(failure.message, 'Uma falha nova do servidor.');
    expect(failure.statusCode, 418);
  });

  test('a local-only code on the wire cannot pretend the app is offline', () {
    final failure = _fromEnvelope(503, {
      'error': {
        'code': 'sem_conexao',
        'message': 'o servidor tentou parecer offline',
      },
    });
    expect(failure.code, ApiErrorCode.desconhecido);
    expect(failure.code, isNot(ApiErrorCode.semConexao));
  });

  test('validation fixture maps details.fields onto each submitted key', () {
    final failure = _fromEnvelope(422, loadFixture('error_validation.json'));

    expect(failure.code, ApiErrorCode.validationFailed);
    expect(failure.fields, {
      'brand': 'Informe a marca.',
      'model': 'Informe o modelo.',
      'plate': 'Informe uma placa válida.',
    });
    expect(ApiFormErrors.fieldsOf(failure), failure.fields);
    expect(ApiFormErrors.bannerOf(failure), isNull);
  });

  test('odometer_rollback fixture keeps neighbour details and not hint', () {
    final failure = _fromEnvelope(
      422,
      loadFixture('error_odometer_rollback.json'),
    );

    expect(failure.code, ApiErrorCode.odometerRollback);
    expect(failure.details['previous_mileage_km'], 98200);
    expect(failure.details['submitted_mileage_km'], 90000);
    expect(failure.details['hint'], contains('correction'));
    expect(failure.fields, isEmpty);

    final rollback = OdometerRollback.fromFailure(failure)!;
    expect(rollback.side, OdometerConflictSide.anterior);
    expect(rollback.explain(failure.message), isNot(contains('correction')));
    expect(rollback.explain(failure.message), isNot(contains('source')));
  });

  test('internal fixture captures request_id', () {
    final failure = _fromEnvelope(
      503,
      loadFixture('error_upstream_unavailable.json'),
    );
    expect(failure.code, ApiErrorCode.internal);
    expect(failure.requestId, 'req-abc-123');
  });
}

ApiFailure _fromEnvelope(int status, Map<String, dynamic> body) {
  return ApiFailure.fromDioException(
    DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: body,
      ),
    ),
  );
}
