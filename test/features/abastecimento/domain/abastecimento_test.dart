import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/volume.dart';

void main() {
  group('Consumption.fromJson', () {
    test('ok keeps the server value and does not invent one', () {
      final consumption = Consumption.fromJson({
        'value': 17.82,
        'unit': 'km_per_liter',
        'status': 'ok',
      });

      expect(consumption.status, ConsumptionStatus.ok);
      expect(consumption.value, 17.82);
      expect(consumption.unit, 'km_per_liter');
    });

    for (final status in [
      'ok',
      'insufficient_data',
      'partial_fill',
      'unavailable',
      'inventado',
    ]) {
      test('value null is kept for status $status', () {
        final consumption = Consumption.fromJson({
          'value': null,
          'unit': 'km_per_liter',
          'status': status,
        });

        expect(consumption.value, isNull);
      });
    }

    test('unknown status falls back to desconhecido, never to ok', () {
      final consumption = Consumption.fromJson({
        'value': 12.5,
        'unit': 'km_per_liter',
        'status': 'computed_later',
      });

      expect(consumption.status, ConsumptionStatus.desconhecido);
      expect(consumption.status, isNot(ConsumptionStatus.ok));
      expect(consumption.value, 12.5);
    });

    test('an integer value still parses', () {
      final consumption = Consumption.fromJson({
        'value': 18,
        'unit': 'km_per_liter',
        'status': 'ok',
      });

      expect(consumption.value, 18);
    });
  });

  group('AbastecimentoFuel', () {
    test('known fuels parse from the wire', () {
      expect(AbastecimentoFuel.fromWire('gasolina'), AbastecimentoFuel.gasolina);
      expect(AbastecimentoFuel.fromWire('etanol'), AbastecimentoFuel.etanol);
      expect(AbastecimentoFuel.fromWire('diesel'), AbastecimentoFuel.diesel);
      expect(AbastecimentoFuel.fromWire('gnv'), AbastecimentoFuel.gnv);
    });

    test('unknown fuel falls back without throwing', () {
      expect(AbastecimentoFuel.fromWire('hidrogenio'), AbastecimentoFuel.desconhecido);
      expect(AbastecimentoFuel.fromWire(null), AbastecimentoFuel.desconhecido);
    });
  });

  group('RefuelingCapability', () {
    test('reads supported and the fuels the server listed', () {
      final capability = RefuelingCapability.fromJson({
        'supported': true,
        'fuel_types': ['gasolina', 'etanol'],
      });

      expect(capability.supported, isTrue);
      expect(capability.fuelTypes, [
        AbastecimentoFuel.gasolina,
        AbastecimentoFuel.etanol,
      ]);
    });

    test('an electric vehicle is unsupported with an empty list', () {
      final capability = RefuelingCapability.fromJson({
        'supported': false,
        'fuel_types': <String>[],
      });

      expect(capability.supported, isFalse);
      expect(capability.fuelTypes, isEmpty);
    });

    test('a missing block does not hide refueling', () {
      final capability = RefuelingCapability.fromJson(null);

      expect(capability.supported, isTrue);
      expect(capability.fuelTypes, isEmpty);
    });
  });

  group('Abastecimento.fromJson', () {
    test('parses a complete fill including optionals', () {
      final fill = Abastecimento.fromJson(_completeJson);

      expect(fill.id, _id);
      expect(fill.vehicleId, _vehicleId);
      expect(fill.occurredOn, const CivilDate(2026, 8, 10));
      expect(fill.mileageKm, 96420);
      expect(fill.volumeMl, 34700);
      expect(fill.totalCostCents, const Money.fromCents(23840));
      expect(fill.pricePerLiterCents, const Money.fromCents(687));
      expect(fill.fuel, AbastecimentoFuel.gasolina);
      expect(fill.fullTank, isTrue);
      expect(fill.stationName, 'Shell Centro');
      expect(fill.notes, 'Completou');
      expect(fill.consumption.status, ConsumptionStatus.ok);
      expect(fill.consumption.value, 17.82);
    });

    test('parses when every optional is null', () {
      final fill = Abastecimento.fromJson({
        ..._completeJson,
        'station_name': null,
        'notes': null,
        'consumption': {
          'value': null,
          'unit': 'km_per_liter',
          'status': 'insufficient_data',
        },
      });

      expect(fill.stationName, isNull);
      expect(fill.notes, isNull);
      expect(fill.consumption.status, ConsumptionStatus.insufficientData);
      expect(fill.consumption.value, isNull);
    });
  });

  group('LastAbastecimento.fromJson', () {
    test('parses the dashboard subset', () {
      final last = LastAbastecimento.fromJson({
        'id': _id,
        'occurred_on': '2026-08-10',
        'total_cost_cents': 26505,
        'volume_ml': 45000,
        'price_per_liter_cents': 589,
        'fuel': 'gasolina',
        'consumption': {
          'value': null,
          'unit': 'km_per_liter',
          'status': 'unavailable',
        },
      });

      expect(last.id, _id);
      expect(last.occurredOn, const CivilDate(2026, 8, 10));
      expect(last.totalCostCents, const Money.fromCents(26505));
      expect(last.volumeMl, 45000);
      expect(last.pricePerLiterCents, const Money.fromCents(589));
      expect(last.fuel, AbastecimentoFuel.gasolina);
      expect(last.consumption.status, ConsumptionStatus.unavailable);
    });
  });

  group('volumeMlFromLitersText', () {
    test('34,7 L becomes 34700 ml', () {
      expect(volumeMlFromLitersText('34,7'), 34700);
    });

    test('the reverse of 34700 is 34,7', () {
      expect(litersTextFromVolumeMl(34700), '34,7');
    });

    test('whole litres have no decimal', () {
      expect(volumeMlFromLitersText('34'), 34000);
      expect(litersTextFromVolumeMl(34000), '34');
    });

    test('a dotted decimal is accepted as litres', () {
      expect(volumeMlFromLitersText('34.7'), 34700);
    });

    test('two decimal places stay exact', () {
      expect(volumeMlFromLitersText('34,75'), 34750);
      expect(litersTextFromVolumeMl(34750), '34,75');
    });

    test('rounds the fourth decimal half up', () {
      expect(volumeMlFromLitersText('34,7515'), 34752);
    });

    test('empty or non-numeric input is null', () {
      expect(volumeMlFromLitersText(''), isNull);
      expect(volumeMlFromLitersText('  '), isNull);
      expect(volumeMlFromLitersText(','), isNull);
    });
  });

  group('defaultAbastecimentoFuel', () {
    test('a single offered fuel is the default', () {
      expect(
        defaultAbastecimentoFuel(
          offered: const [AbastecimentoFuel.diesel],
        ),
        AbastecimentoFuel.diesel,
      );
    });

    test('several fuels prefer the last used when it is still offered', () {
      expect(
        defaultAbastecimentoFuel(
          offered: const [AbastecimentoFuel.gasolina, AbastecimentoFuel.etanol],
          lastUsed: AbastecimentoFuel.etanol,
        ),
        AbastecimentoFuel.etanol,
      );
    });

    test('several fuels without a last used pick the first offered', () {
      expect(
        defaultAbastecimentoFuel(
          offered: const [AbastecimentoFuel.gasolina, AbastecimentoFuel.etanol],
        ),
        AbastecimentoFuel.gasolina,
      );
    });
  });
}

const _id = 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb';
const _vehicleId = '22222222-2222-7222-8222-222222222222';

final _completeJson = {
  'id': _id,
  'vehicle_id': _vehicleId,
  'occurred_on': '2026-08-10',
  'mileage_km': 96420,
  'volume_ml': 34700,
  'total_cost_cents': 23840,
  'price_per_liter_cents': 687,
  'fuel': 'gasolina',
  'full_tank': true,
  'station_name': 'Shell Centro',
  'notes': 'Completou',
  'consumption': {
    'value': 17.82,
    'unit': 'km_per_liter',
    'status': 'ok',
  },
  'created_at': '2026-08-10T15:00:00Z',
  'updated_at': '2026-08-10T15:00:00Z',
};
