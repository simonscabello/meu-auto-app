import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/presentation/item_picker_sheet.dart';

void main() {
  testWidgets('an item already chosen is not added twice', (tester) async {
    List<MaintenanceItem>? picked;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceItemsProvider.overrideWith((ref) async => [_oil, _filter]),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    picked = await Navigator.of(context)
                        .push<List<MaintenanceItem>>(
                          MaterialPageRoute(
                            builder: (_) => const Scaffold(
                              body: ItemPickerSheet(selected: [_oil]),
                            ),
                          ),
                        );
                  },
                  child: const Text('abrir'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Troca de óleo do motor'), findsOneWidget);
    await tester.tap(find.text('Troca de óleo do motor'));
    await tester.pump();
    await tester.tap(find.text('Troca de óleo do motor'));
    await tester.pump();
    await tester.ensureVisible(find.text('Pronto (1)'));
    await tester.tap(find.text('Pronto (1)'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.map((item) => item.id), [_oil.id]);
  });

  testWidgets('tapping a catalogue row three times leaves it selected once', (
    tester,
  ) async {
    List<MaintenanceItem>? picked;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceItemsProvider.overrideWith((ref) async => [_oil, _filter]),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    picked = await Navigator.of(context)
                        .push<List<MaintenanceItem>>(
                          MaterialPageRoute(
                            builder: (_) => const Scaffold(
                              body: ItemPickerSheet(selected: []),
                            ),
                          ),
                        );
                  },
                  child: const Text('abrir'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Troca de óleo do motor'));
    await tester.pump();
    await tester.tap(find.text('Troca de óleo do motor'));
    await tester.pump();
    await tester.tap(find.text('Troca de óleo do motor'));
    await tester.pump();
    await tester.ensureVisible(find.text('Pronto (1)'));
    await tester.tap(find.text('Pronto (1)'));
    await tester.pumpAndSettle();

    expect(picked!.map((item) => item.id), [_oil.id]);
  });

  // Adding to a record that already exists can only append. A tick that looks
  // like it would take a line off is worse than a tick that plainly cannot:
  // removing one means deciding what happens to the clock it was keeping.
  testWidgets('an item already on the record is shown ticked and locked', (
    tester,
  ) async {
    List<MaintenanceItem>? picked;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceItemsProvider.overrideWith((ref) async => [_oil, _filter]),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    picked = await Navigator.of(context)
                        .push<List<MaintenanceItem>>(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              body: ItemPickerSheet(
                                selected: const [],
                                lockedItemIds: {_oil.id},
                                title: 'Adicionar item que faltou',
                              ),
                            ),
                          ),
                        );
                  },
                  child: const Text('abrir'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar item que faltou'), findsOneWidget);
    expect(find.text('Já está neste registro'), findsOneWidget);

    // The locked row does not answer a tap, so it never leaves with the
    // selection.
    await tester.tap(find.text('Troca de óleo do motor'));
    await tester.pump();
    await tester.tap(find.text('Filtro de óleo'));
    await tester.pump();

    await tester.ensureVisible(find.text('Pronto (1)'));
    await tester.tap(find.text('Pronto (1)'));
    await tester.pumpAndSettle();

    expect(picked!.map((item) => item.id), [_filter.id]);
  });
}

const _oil = MaintenanceItem(
  id: 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa',
  slug: 'troca_oleo',
  name: 'Troca de óleo do motor',
  kind: MaintenanceItemKind.maintenance,
  vehicleType: 'car',
  isCustom: false,
  defaultStrategy: MaintenanceStrategy.periodic,
);

const _filter = MaintenanceItem(
  id: 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb',
  slug: 'filtro_oleo',
  name: 'Filtro de óleo',
  kind: MaintenanceItemKind.maintenance,
  vehicleType: 'car',
  isCustom: false,
  defaultStrategy: MaintenanceStrategy.periodic,
);
