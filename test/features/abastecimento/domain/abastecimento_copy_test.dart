import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  group('consumptionPhrase', () {
    test('ok shows one decimal and never invents a number', () {
      expect(
        consumptionPhrase(
          const Consumption(
            value: 17.82,
            unit: 'km_per_liter',
            status: ConsumptionStatus.ok,
          ),
        ),
        '17,8 km/L',
      );
    });

    test('ok with a null value does not invent a number', () {
      expect(
        consumptionPhrase(
          const Consumption(
            unit: 'km_per_liter',
            status: ConsumptionStatus.ok,
          ),
        ),
        'Não foi possível calcular o consumo deste registro.',
      );
    });

    test('partial_fill has its own sentence and no figure', () {
      expect(
        consumptionPhrase(
          const Consumption(
            value: 17.82,
            unit: 'km_per_liter',
            status: ConsumptionStatus.partialFill,
          ),
        ),
        'Abastecimento parcial — o consumo entra no próximo tanque cheio.',
      );
    });

    test('insufficient_data has its own sentence and no figure', () {
      expect(
        consumptionPhrase(
          const Consumption(
            unit: 'km_per_liter',
            status: ConsumptionStatus.insufficientData,
          ),
        ),
        'Consumo disponível a partir do próximo tanque cheio.',
      );
    });

    test('unavailable has its own sentence and no figure', () {
      expect(
        consumptionPhrase(
          const Consumption(
            unit: 'km_per_liter',
            status: ConsumptionStatus.unavailable,
          ),
        ),
        'Não foi possível calcular o consumo deste registro.',
      );
    });

    test('desconhecido is treated as unavailable', () {
      expect(
        consumptionPhrase(
          const Consumption(
            value: 9.9,
            unit: 'km_per_liter',
            status: ConsumptionStatus.desconhecido,
          ),
        ),
        'Não foi possível calcular o consumo deste registro.',
      );
    });
  });

  test('abastecimentoFuelLabel names each known fuel', () {
    expect(abastecimentoFuelLabel(AbastecimentoFuel.gasolina), 'Gasolina');
    expect(abastecimentoFuelLabel(AbastecimentoFuel.etanol), 'Etanol');
    expect(abastecimentoFuelLabel(AbastecimentoFuel.diesel), 'Diesel');
    expect(abastecimentoFuelLabel(AbastecimentoFuel.gnv), 'GNV');
    expect(abastecimentoFuelLabel(AbastecimentoFuel.desconhecido), 'Combustível');
  });
}
