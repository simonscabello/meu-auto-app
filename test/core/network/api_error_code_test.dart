import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_error_code.dart';

void main() {
  test('known wire codes map onto the contract enum', () {
    const wires = {
      'validation_failed': ApiErrorCode.validationFailed,
      'unauthorized': ApiErrorCode.unauthorized,
      'forbidden': ApiErrorCode.forbidden,
      'not_found': ApiErrorCode.notFound,
      'method_not_allowed': ApiErrorCode.methodNotAllowed,
      'conflict': ApiErrorCode.conflict,
      'odometer_rollback': ApiErrorCode.odometerRollback,
      'rate_limited': ApiErrorCode.rateLimited,
      'internal': ApiErrorCode.internal,
    };

    for (final entry in wires.entries) {
      expect(ApiErrorCode.fromWire(entry.key), entry.value, reason: entry.key);
    }
  });

  test('invented wire code falls back to desconhecido without throwing', () {
    expect(ApiErrorCode.fromWire('algo_novo'), ApiErrorCode.desconhecido);
    expect(ApiErrorCode.fromWire(null), ApiErrorCode.desconhecido);
    expect(ApiErrorCode.fromWire(''), ApiErrorCode.desconhecido);
  });
}
