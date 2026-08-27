import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/catalog/domain/vehicle_catalog.dart';
import 'package:meu_auto/features/catalog/presentation/vehicle_catalog_sheet.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

/// Both widgets here are pure — no `ref`, no provider — so the copy can be
/// tested without a `ProviderScope`. That is the reason they are shaped that
/// way, and these are the decisions worth pinning: what a missing valuation
/// reads as, and whether the form admits an existing link.
void main() {
  VehicleCatalogSelection selection({FipePrice? price}) {
    return VehicleCatalogSelection(
      modelYearId: 'year-1',
      brandName: 'Toyota',
      modelName: 'PRIUS 1.8 16V 5p Aut. (Híbrido)',
      modelYear: 2017,
      fuelType: FuelType.hibrido,
      fipeCode: '002129-6',
      fipePrice: price,
    );
  }

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('VehicleCatalogSummary', () {
    testWidgets('shows the valuation and the month it refers to', (
      tester,
    ) async {
      await pump(
        tester,
        VehicleCatalogSummary(
          selection: selection(
            price: FipePrice(
              price: const Money.fromCents(8005500),
              referenceMonth: const CivilDate(2026, 8, 1),
              collectedAt: DateTime(2026, 8, 26),
            ),
          ),
          onChange: () {},
          onClear: () {},
        ),
      );

      expect(find.text('Toyota'), findsOneWidget);
      expect(find.text('PRIUS 1.8 16V 5p Aut. (Híbrido)'), findsOneWidget);
      expect(find.text(r'R$ 80.055,00'), findsOneWidget);
      expect(find.text('Valor FIPE de agosto de 2026'), findsOneWidget);
    });

    testWidgets('a missing valuation reads as unavailable, not as an error', (
      tester,
    ) async {
      // The source being unreachable is a documented 200 with a null price.
      // The card must still show the car — registration works without a
      // valuation, and wording this as a failure would suggest otherwise.
      await pump(
        tester,
        VehicleCatalogSummary(
          selection: selection(),
          onChange: () {},
          onClear: () {},
        ),
      );

      expect(find.text('Valor FIPE indisponível no momento.'), findsOneWidget);
      expect(find.text('PRIUS 1.8 16V 5p Aut. (Híbrido)'), findsOneWidget);
      expect(find.textContaining('erro'), findsNothing);
    });

    testWidgets('disabled while the form is submitting', (tester) async {
      var changed = false;
      await pump(
        tester,
        VehicleCatalogSummary(
          selection: selection(),
          enabled: false,
          onChange: () => changed = true,
          onClear: () {},
        ),
      );

      await tester.tap(find.text('Trocar'));
      await tester.pump();
      expect(changed, isFalse);
    });
  });

  group('VehicleCatalogPrompt', () {
    testWidgets('offers the search and says typing by hand still works', (
      tester,
    ) async {
      await pump(tester, VehicleCatalogPrompt(onPressed: () {}));

      expect(find.text('Buscar na tabela FIPE'), findsOneWidget);
      expect(find.textContaining('digitar tudo à mão'), findsOneWidget);
    });

    testWidgets('an already-linked vehicle says so instead of implying it '
        'was typed by hand', (tester) async {
      await pump(
        tester,
        VehicleCatalogPrompt(onPressed: () {}, alreadyLinked: true),
      );

      expect(find.text('Trocar na tabela FIPE'), findsOneWidget);
      expect(
        find.textContaining('cadastrado pela tabela FIPE'),
        findsOneWidget,
      );
    });
  });
}
