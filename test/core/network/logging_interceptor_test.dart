import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/logging_interceptor.dart';

void main() {
  test('redacts Authorization and token fields in any body', () {
    final logs = <String>[];
    final interceptor = LoggingInterceptor(logPrint: logs.add);

    final options = RequestOptions(
      path: '/auth/refresh',
      method: 'POST',
      headers: {'Authorization': 'Bearer super-secret-access'},
      data: {
        'password': 'hunter2',
        'access_token': 'access-secret',
        'refresh_token': 'refresh-secret',
        'token': 'reset-secret',
        'nested': {'refresh_token': 'nested-secret'},
      },
    );
    interceptor.onRequest(options, RequestInterceptorHandler());
    interceptor.onResponse(
      Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'access_token': 'returned-access',
          'refresh_token': 'returned-refresh',
        },
      ),
      ResponseInterceptorHandler(),
    );

    final joined = logs.join('\n');
    expect(joined, contains('POST'));
    expect(joined, contains('/auth/refresh'));
    expect(joined, contains('200'));
    expect(joined, isNot(contains('super-secret-access')));
    expect(joined, isNot(contains('hunter2')));
    expect(joined, isNot(contains('access-secret')));
    expect(joined, isNot(contains('refresh-secret')));
    expect(joined, isNot(contains('reset-secret')));
    expect(joined, isNot(contains('nested-secret')));
    expect(joined, isNot(contains('returned-access')));
    expect(joined, isNot(contains('returned-refresh')));
    expect(joined, contains('[redacted]'));
  });
}
