import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_detail_screen.dart';
import 'package:meu_auto/shared/widgets/app_plate_chip.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  testWidgets('the short name is the title and the full model sits under it', (
    tester,
  ) async {
    await _pump(tester, _prius());

    expect(find.text('Toyota Prius'), findsOneWidget);
    expect(find.text('PRIUS 1.8 16V 5p Aut. (Híbrido)'), findsNWidgets(2));
    expect(find.byType(AppPlateChip), findsOneWidget);
  });

  testWidgets('the strip answers mileage, year and fuel', (tester) async {
    await _pump(tester, _prius());

    expect(find.text('Odômetro'), findsOneWidget);
    expect(find.text('139.011\u00A0km', findRichText: true), findsOneWidget);
    expect(find.text('2017', findRichText: true), findsOneWidget);
    expect(find.text('Híbrido', findRichText: true), findsOneWidget);
    expect(find.text('Odômetro atualizado em 24/09/2026'), findsOneWidget);
  });

  testWidgets('documents and identity are two groups of short facts', (
    tester,
  ) async {
    await _pump(tester, _prius());

    expect(find.text('Documentação'), findsOneWidget);
    expect(find.text('Renavam'), findsOneWidget);
    expect(find.text('12345678901'), findsOneWidget);
    expect(find.text('Identificação'), findsOneWidget);
    expect(find.text('Prata'), findsOneWidget);
    // The plate is drawn under the title and not repeated as a row.
    expect(find.text('Placa'), findsNothing);
  });

  testWidgets('with no renavam or chassi, the group offers to add them', (
    tester,
  ) async {
    var edited = 0;
    await _pump(
      tester,
      Vehicle(
        id: 'v2',
        vehicleType: VehicleType.car,
        brand: 'Volkswagen',
        model: 'Gol',
        plate: 'BRA2E19',
        currentMileageKm: 87450,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      onEdit: () => edited++,
    );

    await tester.tap(find.text('Adicionar renavam e chassi'));
    await tester.pump();
    expect(edited, 1);
  });

  testWidgets('a nickname is the title, with make and model under it', (
    tester,
  ) async {
    await _pump(tester, _prius(nickname: 'Pretinho'));

    expect(find.text('Pretinho'), findsNWidgets(2));
    expect(find.text('Toyota PRIUS 1.8 16V 5p Aut. (Híbrido)'), findsOneWidget);
  });

  testWidgets('a bare car renders without empty groups', (tester) async {
    await _pump(
      tester,
      Vehicle(
        id: 'v2',
        vehicleType: VehicleType.car,
        brand: 'Fiat',
        model: 'Argo',
        currentMileageKm: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    expect(find.text('Fiat Argo'), findsOneWidget);
    expect(find.text('Documentação'), findsNothing);
    expect(find.byType(AppPlateChip), findsNothing);
  });

  testWidgets('edit is the pencil and delete waits in the menu', (
    tester,
  ) async {
    var edited = 0;
    var deleted = 0;
    await _pump(
      tester,
      _prius(),
      onEdit: () => edited++,
      onDelete: () => deleted++,
    );

    expect(find.text('Excluir veículo'), findsNothing);
    await tester.tap(find.byTooltip('Editar veículo'));
    await tester.pump();
    expect(edited, 1);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir veículo'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('while deleting, neither action can be pressed again', (
    tester,
  ) async {
    await _pump(
      tester,
      _prius(),
      deleting: true,
      onEdit: () {},
      onDelete: () {},
    );

    expect(find.byIcon(Icons.more_vert), findsNothing);
    final pencil = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.edit_outlined),
    );
    expect(pencil.onPressed, isNull);
  });

  group('360x640 with the font turned up', () {
    for (final theme in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      testWidgets('vehicle detail lays out in ${theme.key}', (tester) async {
        tester.view.physicalSize = const Size(360, 640) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pump(
          tester,
          _prius(nickname: 'Carro da família', mileage: 1234567),
          theme: theme.value,
          scale: 1.3,
          onEdit: () {},
          onDelete: () {},
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  Vehicle vehicle, {
  ThemeData? theme,
  double scale = 1,
  bool deleting = false,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          size: const Size(360, 640),
        ),
        child: VehicleDetailContent(
          vehicle: vehicle,
          deleting: deleting,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    ),
  );
}

Vehicle _prius({String? nickname, int mileage = 139011}) {
  return Vehicle(
    id: 'v1',
    vehicleType: VehicleType.car,
    brand: 'Toyota',
    model: 'PRIUS 1.8 16V 5p Aut. (Híbrido)',
    manufactureYear: 2017,
    modelYear: 2017,
    plate: 'QAF5G33',
    renavam: '12345678901',
    chassis: 'JTDKB3FU0H3012345',
    fuelType: FuelType.hibrido,
    color: 'Prata',
    nickname: nickname,
    fipeCode: '002129-6',
    currentMileageKm: mileage,
    currentMileageAt: const CivilDate(2026, 9, 24),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}
