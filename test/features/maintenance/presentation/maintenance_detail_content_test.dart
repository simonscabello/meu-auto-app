import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_detail_screen.dart';

void main() {
  group('warranty', () {
    testWidgets('states both limits joined by "ou" — whichever comes first', (
      tester,
    ) async {
      await _pump(
        tester,
        _record(
          items: [
            _item(
              name: 'Bateria',
              warrantyUntil: const CivilDate(2028, 8, 20),
              warrantyUntilKm: 138200,
            ),
          ],
        ),
      );

      expect(
        find.text('Garantia até 20/08/2028 ou até 138.200 km'),
        findsOneWidget,
      );
    });

    testWidgets('a time-only warranty says nothing about distance', (
      tester,
    ) async {
      await _pump(
        tester,
        _record(
          items: [
            _item(name: 'Bateria', warrantyUntil: const CivilDate(2028, 8, 20)),
          ],
        ),
      );

      expect(find.text('Garantia até 20/08/2028'), findsOneWidget);
      expect(find.textContaining('km'), findsWidgets); // o odômetro do registro
      expect(find.textContaining('ou até'), findsNothing);
    });

    testWidgets('no warranty shows no line at all, not "sem garantia"', (
      tester,
    ) async {
      await _pump(tester, _record(items: [_item(name: 'Alinhamento')]));

      expect(find.textContaining('Garantia'), findsNothing);
      expect(find.textContaining('sem garantia'), findsNothing);
    });

    testWidgets('never claims the warranty is active or expired', (
      tester,
    ) async {
      // Saying so would mean comparing to today, and whether a warranty is
      // running out is a rule the server owns — it answers it in /alerts.
      await _pump(
        tester,
        _record(
          items: [
            _item(name: 'Bateria', warrantyUntil: const CivilDate(2020, 1, 1)),
          ],
        ),
      );

      expect(find.textContaining('ativa'), findsNothing);
      expect(find.textContaining('vencida'), findsNothing);
      expect(find.textContaining('válida'), findsNothing);
    });
  });

  group('declared records', () {
    testWidgets('carry an explanation of what they are worth', (tester) async {
      await _pump(tester, _record(kind: MaintenanceRecordKind.declared));

      expect(find.textContaining('Informado pelo dono'), findsOneWidget);
    });

    testWidgets('a performed record carries no such banner', (tester) async {
      await _pump(tester, _record());

      expect(find.textContaining('Informado pelo dono'), findsNothing);
    });
  });

  testWidgets('a zero total is not shown as R\$ 0,00', (tester) async {
    await _pump(tester, _record(totalCents: 0));

    expect(find.text('Total'), findsNothing);
    expect(find.textContaining('0,00'), findsNothing);
  });

  testWidgets('the header pairs mileage with the workshop when there is one', (
    tester,
  ) async {
    await _pump(tester, _record(workshop: 'Auto Center Silva'));

    expect(find.text('10 de agosto de 2026'), findsOneWidget);
    expect(find.text('98.200 km · Auto Center Silva'), findsOneWidget);
  });

  testWidgets('without a workshop the header is just the mileage', (
    tester,
  ) async {
    await _pump(tester, _record(workshop: null));

    expect(find.text('98.200 km'), findsOneWidget);
  });

  group('360x640 with the font turned up', () {
    for (final theme in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      testWidgets('a full record lays out in ${theme.key}', (tester) async {
        tester.view.physicalSize = const Size(360, 640) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pump(
          tester,
          _record(
            kind: MaintenanceRecordKind.declared,
            workshop: 'Oficina do Zé — Rua das Palmeiras',
            items: [
              _item(
                name: 'Troca de óleo do motor',
                warrantyUntil: const CivilDate(2027, 8, 10),
                warrantyUntilKm: 108200,
              ),
              _item(name: 'Filtro de óleo'),
              _item(name: 'Filtro de ar do motor'),
            ],
          ),
          theme: theme.value,
          scale: 1.3,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  MaintenanceRecord record, {
  ThemeData? theme,
  double scale = 1.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: MaintenanceDetailContent(record: record)),
      ),
    ),
  );
}

MaintenanceRecord _record({
  MaintenanceRecordKind kind = MaintenanceRecordKind.performed,
  String? workshop = 'Auto Center Silva',
  int totalCents = 42000,
  List<MaintenanceRecordItem>? items,
}) {
  return MaintenanceRecord(
    id: '11111111-1111-7111-8111-111111111111',
    vehicleId: '22222222-2222-7222-8222-222222222222',
    occurredOn: const CivilDate(2026, 8, 10),
    mileageKm: 98200,
    kind: kind,
    workshopName: workshop,
    totalCostCents: Money.fromCents(totalCents),
    items: items ?? [_item(name: 'Troca de óleo do motor')],
    createdAt: DateTime(2026, 8, 10),
    updatedAt: DateTime(2026, 8, 10),
  );
}

MaintenanceRecordItem _item({
  required String name,
  CivilDate? warrantyUntil,
  int? warrantyUntilKm,
}) {
  return MaintenanceRecordItem(
    id: '33333333-3333-7333-8333-333333333333',
    maintenanceItemId: '44444444-4444-7444-8444-444444444444',
    itemSlug: 'troca_oleo',
    itemName: name,
    warrantyUntil: warrantyUntil,
    warrantyUntilKm: warrantyUntilKm,
  );
}
