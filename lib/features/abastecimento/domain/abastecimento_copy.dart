import 'package:intl/intl.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';

const _unavailablePhrase =
    'Não foi possível calcular o consumo deste registro.';

final _oneDecimal = NumberFormat('0.0', 'pt_BR');

/// Words for a consumption the server already decided. Never computes km/L.
String consumptionPhrase(Consumption consumption) {
  switch (consumption.status) {
    case ConsumptionStatus.ok:
      final value = consumption.value;
      if (value == null) return _unavailablePhrase;
      return '${_oneDecimal.format(value)} km/L';
    case ConsumptionStatus.partialFill:
      return 'Abastecimento parcial — o consumo entra no próximo tanque cheio.';
    case ConsumptionStatus.insufficientData:
      return 'Consumo disponível a partir do próximo tanque cheio.';
    case ConsumptionStatus.unavailable:
    case ConsumptionStatus.desconhecido:
      return _unavailablePhrase;
  }
}

/// The figure [AppMetric] shows when [Consumption.status] is ok. Null means
/// the third slot should be the status phrase instead.
String? consumptionValueText(Consumption consumption) {
  if (consumption.status != ConsumptionStatus.ok) return null;
  final value = consumption.value;
  if (value == null) return null;
  return _oneDecimal.format(value);
}

String abastecimentoFuelLabel(AbastecimentoFuel fuel) {
  return switch (fuel) {
    AbastecimentoFuel.gasolina => 'Gasolina',
    AbastecimentoFuel.etanol => 'Etanol',
    AbastecimentoFuel.diesel => 'Diesel',
    AbastecimentoFuel.gnv => 'GNV',
    AbastecimentoFuel.desconhecido => 'Combustível',
  };
}

const abastecimentoRegisteredMessage = 'Abastecimento registrado.';
const abastecimentoUpdatedMessage = 'Abastecimento atualizado.';
const abastecimentoDeletedMessage = 'Abastecimento excluído.';

const abastecimentoEmptyTitle = 'Nenhum abastecimento registrado';
const abastecimentoEmptyMessage =
    'Registre o próximo abastecimento para começar a acompanhar '
    'os gastos do seu carro.';
const abastecimentoRegisterLabel = 'Registrar abastecimento';

/// Quiet dashboard invite when the car can refuel but has no fill yet.
const lastAbastecimentoEmptyPrompt = 'Registre o primeiro abastecimento';

const abastecimentoDeleteTitle = 'Excluir este abastecimento?';
const abastecimentoDeleteMessage =
    'A quilometragem registrada junto também será apagada.';
