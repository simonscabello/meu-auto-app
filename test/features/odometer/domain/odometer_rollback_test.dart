import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';

/// The server rejects a reading that does not fit its neighbours in time, and
/// it does so in two shapes. The contract documents only the first.
void main() {
  test('a conflict with the previous reading is unpacked', () {
    final rollback = OdometerRollback.fromFailure(
      _failure({
        'previous_mileage_km': 98200,
        'previous_occurred_on': '2026-08-10',
        'submitted_mileage_km': 90000,
        'hint': 'Se o painel foi trocado ... reenvie com source "correction".',
      }),
    );

    expect(rollback, isNotNull);
    expect(rollback!.side, OdometerConflictSide.anterior);
    expect(rollback.neighbourMileageKm, 98200);
    expect(rollback.neighbourOccurredOn, const CivilDate(2026, 8, 10));
    expect(rollback.submittedMileageKm, 90000);
  });

  test('a conflict with a later reading is unpacked as the other side', () {
    final rollback = OdometerRollback.fromFailure(
      _failure({
        'next_mileage_km': 98200,
        'next_occurred_on': '2026-09-15',
        'submitted_mileage_km': 99000,
      }),
    );

    expect(rollback!.side, OdometerConflictSide.posterior);
    expect(rollback.neighbourMileageKm, 98200);
    expect(rollback.neighbourOccurredOn, const CivilDate(2026, 9, 15));
  });

  test('a failure that is not a rollback yields null', () {
    const failure = ApiFailure(
      code: ApiErrorCode.validationFailed,
      message: 'Dados inválidos.',
      fields: {'mileage_km': 'Informe a quilometragem.'},
    );
    expect(OdometerRollback.fromFailure(failure), isNull);
  });

  group('the sentence', () {
    test('names the neighbour and the submitted value', () {
      final rollback = OdometerRollback.fromFailure(
        _failure({
          'previous_mileage_km': 98200,
          'previous_occurred_on': '2026-08-10',
          'submitted_mileage_km': 90000,
        }),
      )!;

      expect(
        rollback.explain('mensagem do servidor'),
        'Em 10/08/2026 o carro já estava com 98.200 km. '
        'Você informou 90.000 km, que é menos.',
      );
    });

    test('worded differently when the conflict is with a later reading', () {
      final rollback = OdometerRollback.fromFailure(
        _failure({
          'next_mileage_km': 98200,
          'next_occurred_on': '2026-09-15',
          'submitted_mileage_km': 99000,
        }),
      )!;

      expect(
        rollback.explain('mensagem do servidor'),
        'Existe um registro de 15/09/2026 com 98.200 km. '
        'Você informou 99.000 km, que ficaria acima dele.',
      );
    });

    test('falls back to the server message when a detail is missing', () {
      final rollback = OdometerRollback.fromFailure(
        _failure({'previous_mileage_km': 98200}),
      )!;

      expect(rollback.explain('mensagem do servidor'), 'mensagem do servidor');
    });

    test('survives details being absent entirely', () {
      final rollback = OdometerRollback.fromFailure(_failure(const {}))!;
      expect(rollback.side, OdometerConflictSide.anterior);
      expect(rollback.explain('mensagem do servidor'), 'mensagem do servidor');
    });

    test('never leaks the word the server uses for the override', () {
      final rollback = OdometerRollback.fromFailure(
        _failure({
          'previous_mileage_km': 98200,
          'previous_occurred_on': '2026-08-10',
          'submitted_mileage_km': 90000,
          'hint': 'reenvie com source "correction".',
        }),
      )!;

      final shown = [
        rollback.explain('mensagem do servidor'),
        rollback.overrideHelp,
        OdometerRollback.overrideLabel,
      ].join(' ');
      expect(shown.toLowerCase(), isNot(contains('correction')));
      expect(shown.toLowerCase(), isNot(contains('source')));
    });
  });

  test('numeric details arriving as strings are still read', () {
    final rollback = OdometerRollback.fromFailure(
      _failure({
        'previous_mileage_km': '98200',
        'previous_occurred_on': '2026-08-10',
        'submitted_mileage_km': '90000',
      }),
    )!;

    expect(rollback.neighbourMileageKm, 98200);
    expect(rollback.submittedMileageKm, 90000);
  });
}

ApiFailure _failure(Map<String, dynamic> details) {
  return ApiFailure(
    code: ApiErrorCode.odometerRollback,
    message: 'A quilometragem informada é menor que a do registro anterior.',
    details: details,
    statusCode: 422,
  );
}
