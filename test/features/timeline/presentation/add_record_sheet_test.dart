import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/timeline/presentation/add_record_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';

void main() {
  testWidgets('abastecimento is the first action when the car refuels', (
    tester,
  ) async {
    await _pump(tester, _vehicle());

    final rows = tester
        .widgetList<AppListRow>(find.byType(AppListRow))
        .toList();
    expect(rows, isNotEmpty);
    expect(rows.first.title, 'Registrar abastecimento');
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
        .widgetList<AppListRow>(find.byType(AppListRow))
        .map((row) => row.title)
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

  testWidgets('the action list keeps the standard side margins', (
    tester,
  ) async {
    await _pump(tester, _vehicle());

    final groupRect = tester.getRect(find.byType(AppGroup));
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;

    expect(groupRect.left, AppSpacing.page);
    expect(groupRect.right, screenWidth - AppSpacing.page);
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
