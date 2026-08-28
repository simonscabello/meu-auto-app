import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_switcher_sheet.dart';

/// The sheet was a stock `ListTile` list with `selected: true` on the current
/// car, and Material paints a selected tile's **title and subtitle** in the
/// primary colour. The result was the car name and its plate rendered as two
/// teal lines of different sizes, which reads as a broken row rather than as
/// a chosen one.
void main() {
  testWidgets('the car in use is marked with a tick, not with colour', (
    tester,
  ) async {
    await _pump(tester, selectedId: 'v1');

    expect(find.byIcon(Icons.check), findsOneWidget);

    final theme = AppTheme.light;
    for (final label in ['Prius', 'QAF5G33']) {
      final style = tester.widget<Text>(find.text(label)).style;
      expect(
        style?.color,
        isNot(theme.colorScheme.primary),
        reason: '$label is painted as if it were a link',
      );
    }
  });

  testWidgets('name and plate are two different type sizes', (tester) async {
    await _pump(tester, selectedId: 'v1');

    final name = tester.widget<Text>(find.text('Prius')).style;
    final plate = tester.widget<Text>(find.text('QAF5G33')).style;
    expect(name?.fontSize, isNotNull);
    expect(plate?.fontSize, isNotNull);
    expect(plate!.fontSize, lessThan(name!.fontSize!));
  });

  // The tick is the state of the row, not an action of its own. A dead spot on
  // the right-hand edge of a tappable row is the kind of thing people blame
  // themselves for.
  testWidgets('tapping anywhere on the row picks the car, tick included', (
    tester,
  ) async {
    final picked = <String>[];
    await _pump(tester, selectedId: 'v1', onSelect: (v) => picked.add(v.id));

    await tester.tap(find.text('Corolla'));
    await tester.tap(find.byIcon(Icons.check));

    expect(picked, ['v2', 'v1']);
  });

  testWidgets('a car with no plate does not render an empty second line', (
    tester,
  ) async {
    await _pump(tester, selectedId: 'v3');
    expect(find.text('Sem placa'), findsNothing);
    expect(find.text('Fusca'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  String? selectedId,
  ValueChanged<Vehicle>? onSelect,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: VehicleSwitcherContent(
          vehicles: [
            _vehicle(id: 'v1', nickname: 'Prius', plate: 'QAF5G33'),
            _vehicle(id: 'v2', nickname: 'Corolla', plate: 'ABC1D23'),
            _vehicle(id: 'v3', nickname: 'Fusca'),
          ],
          selectedId: selectedId,
          onSelect: onSelect,
        ),
      ),
    ),
  );
}

Vehicle _vehicle({
  required String id,
  required String nickname,
  String? plate,
}) {
  return Vehicle(
    id: id,
    vehicleType: VehicleType.car,
    brand: 'Toyota',
    model: 'Modelo',
    modelYear: 2020,
    nickname: nickname,
    plate: plate,
    currentMileageKm: 138798,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}
