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
    testWidgets('carry a badge and what they are worth', (tester) async {
      await _pump(tester, _record(kind: MaintenanceRecordKind.declared));

      expect(find.text('Informado'), findsOneWidget);
      expect(find.textContaining('Sem comprovante'), findsOneWidget);
    });

    testWidgets('a performed record carries no such badge', (tester) async {
      await _pump(tester, _record());

      expect(find.text('Informado'), findsNothing);
      expect(find.textContaining('Sem comprovante'), findsNothing);
    });
  });

  testWidgets('a zero total is not shown as R\$ 0,00', (tester) async {
    await _pump(tester, _record(totalCents: 0));

    expect(find.text('Total'), findsNothing);
    expect(find.textContaining('0,00'), findsNothing);
  });

  // The header says what was done and where; the strip, when, at what
  // mileage and for how much.
  testWidgets('the header names the work and the workshop', (tester) async {
    await _pump(tester, _record(workshop: 'Auto Center Silva'));

    expect(find.text('Troca de óleo do motor'), findsWidgets);
    expect(find.text('Auto Center Silva'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('10/08/2026'), findsOneWidget);
    expect(find.text('Odômetro'), findsOneWidget);
    expect(find.text('98.200 km'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('R\$ 420,00'), findsOneWidget);
  });

  testWidgets('without a workshop there is no line under the title', (
    tester,
  ) async {
    await _pump(tester, _record(workshop: null));

    expect(find.text('98.200 km'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
  });

  // A care marked "Feito" carries no mileage and no cost: a strip of one date
  // would be a box around a single word, so the date goes under the title.
  testWidgets('with no figures, the date is a sentence under the title', (
    tester,
  ) async {
    await _pump(
      tester,
      _record(totalCents: 0, mileageKm: null, workshop: 'Posto Central'),
    );

    expect(find.text('10 de agosto de 2026 · Posto Central'), findsOneWidget);
    expect(find.text('Data'), findsNothing);
  });

  group('the title', () {
    MaintenanceRecord withItems(List<String> names, {String? revisao}) {
      return _record(
        items: [
          if (revisao != null) _item(name: revisao, slug: 'revisao'),
          for (final name in names) _item(name: name),
        ],
      );
    }

    test('one item is its name', () {
      expect(maintenanceRecordTitle(withItems(['Bateria'])), 'Bateria');
    });

    test('two items are both named', () {
      expect(
        maintenanceRecordTitle(withItems(['Troca de óleo', 'Filtro de óleo'])),
        'Troca de óleo e Filtro de óleo',
      );
    });

    test('more than two name the first and count the rest', () {
      expect(
        maintenanceRecordTitle(withItems(['Troca de óleo', 'Filtro', 'Velas'])),
        'Troca de óleo e mais 2 itens',
      );
    });

    test('a revisão names the visit', () {
      expect(
        maintenanceRecordTitle(
          withItems(['Troca de óleo', 'Filtro'], revisao: 'Revisão'),
        ),
        'Revisão e mais 2 itens',
      );
    });
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
  // The case this exists for: a revisão registered with five items, and the
  // brake fluid remembered afterwards. The only ways out used to be leaving
  // the history wrong or retracting the record and typing all six again.
  group('adding an item that was forgotten', () {
    testWidgets('the way in is the last row of the group, and it fires', (
      tester,
    ) async {
      var tapped = false;
      await _pump(tester, _record(), onAddItem: () => tapped = true);

      expect(find.text('Adicionar item'), findsOneWidget);
      await tester.tap(find.text('Adicionar item'));
      expect(tapped, isTrue);
    });

    testWidgets('no row at all when the caller offers no way to add', (
      tester,
    ) async {
      await _pump(tester, _record());
      expect(find.text('Adicionar item'), findsNothing);
    });

    // Two writes in flight on one record is how a duplicate line gets in.
    testWidgets('the row stops taking taps while the write is in flight', (
      tester,
    ) async {
      var taps = 0;
      await _pump(tester, _record(), onAddItem: () => taps++, addingItem: true);

      await tester.tap(find.text('Adicionar item'));
      expect(taps, 0);
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  MaintenanceRecord record, {
  ThemeData? theme,
  double scale = 1.0,
  VoidCallback? onAddItem,
  bool addingItem = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: MaintenanceDetailContent(
            record: record,
            onAddItem: onAddItem,
            addingItem: addingItem,
          ),
        ),
      ),
    ),
  );
}

MaintenanceRecord _record({
  MaintenanceRecordKind kind = MaintenanceRecordKind.performed,
  String? workshop = 'Auto Center Silva',
  int totalCents = 42000,
  int? mileageKm = 98200,
  List<MaintenanceRecordItem>? items,
}) {
  return MaintenanceRecord(
    id: '11111111-1111-7111-8111-111111111111',
    vehicleId: '22222222-2222-7222-8222-222222222222',
    occurredOn: const CivilDate(2026, 8, 10),
    mileageKm: mileageKm,
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
  String slug = 'troca_oleo',
  CivilDate? warrantyUntil,
  int? warrantyUntilKm,
}) {
  return MaintenanceRecordItem(
    id: 'line-$name',
    maintenanceItemId: '44444444-4444-7444-8444-444444444444',
    itemSlug: slug,
    itemName: name,
    warrantyUntil: warrantyUntil,
    warrantyUntilKm: warrantyUntilKm,
  );
}
