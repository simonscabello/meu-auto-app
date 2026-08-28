import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/timeline/presentation/add_record_sheet.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

void main() {
  testWidgets('abastecimento is the first action when the car refuels', (
    tester,
  ) async {
    await _pump(tester, _vehicle());

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles, isNotEmpty);
    expect((tiles.first.title as Text).data, 'Registrar abastecimento');
    expect(find.text('Atualizar quilometragem'), findsOneWidget);
  });

  testWidgets('an electric vehicle does not offer abastecimento', (
    tester,
  ) async {
    await _pump(
      tester,
      _vehicle(
        refueling: RefuelingCapability.unsupported,
        fuelType: FuelType.eletrico,
      ),
    );

    expect(find.text('Registrar abastecimento'), findsNothing);
    expect(find.text('Atualizar quilometragem'), findsOneWidget);
  });

  testWidgets('actions follow real frequency', (tester) async {
    await _pump(tester, _vehicle());

    final labels = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title as Text).data)
        .toList();
    expect(labels, [
      'Registrar abastecimento',
      'Atualizar quilometragem',
      'Registrar manutenção',
      'Registrar IPVA',
      'Registrar licenciamento',
      'Registrar seguro',
    ]);
  });
}

Future<void> _pump(WidgetTester tester, Vehicle vehicle) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedVehicleProvider.overrideWith((ref) => AsyncData(vehicle)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AddRecordSheet()),
      ),
    ),
  );
}

Vehicle _vehicle({
  RefuelingCapability refueling = const RefuelingCapability(
    supported: true,
    fuelTypes: [AbastecimentoFuel.gasolina, AbastecimentoFuel.etanol],
  ),
  FuelType fuelType = FuelType.flex,
}) {
  return Vehicle(
    id: '11111111-1111-7111-8111-111111111111',
    vehicleType: VehicleType.car,
    brand: 'Fiat',
    model: 'Argo',
    fuelType: fuelType,
    currentMileageKm: 96420,
    refueling: refueling,
    createdAt: DateTime.utc(2026, 8, 26),
    updatedAt: DateTime.utc(2026, 8, 26),
  );
}
