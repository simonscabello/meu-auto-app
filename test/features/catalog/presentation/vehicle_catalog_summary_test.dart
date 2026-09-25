import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
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

  Future<void> pump(WidgetTester tester, Widget child, {double scale = 1}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            size: const Size(360, 640),
          ),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
  }

  group('VehicleCatalogSummary', () {
    testWidgets('shows the car, the valuation and the month it refers to', (
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

      expect(find.text('PRIUS 1.8 16V 5p Aut. (Híbrido)'), findsOneWidget);
      expect(find.text('Toyota\u00A0· 2017\u00A0· Híbrido'), findsOneWidget);
      expect(find.text('R\$\u00A080.055,00'), findsOneWidget);
      expect(find.text('Referência: agosto de 2026'), findsOneWidget);
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

      expect(find.text('Valor FIPE'), findsOneWidget);
      expect(
        find.text('Indisponível agora. O cadastro funciona sem ele.'),
        findsOneWidget,
      );
      expect(find.text('PRIUS 1.8 16V 5p Aut. (Híbrido)'), findsOneWidget);
      expect(find.textContaining('erro'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('change and remove reach their callbacks', (tester) async {
      var changed = 0;
      var cleared = 0;
      await pump(
        tester,
        VehicleCatalogSummary(
          selection: selection(),
          onChange: () => changed++,
          onClear: () => cleared++,
        ),
      );

      await tester.tap(find.text('Trocar'));
      await tester.tap(find.text('Remover'));
      await tester.pump();
      expect(changed, 1);
      expect(cleared, 1);
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

    testWidgets('lays out at 360px with the font turned up', (tester) async {
      tester.view.physicalSize = const Size(360, 640) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pump(
        tester,
        VehicleCatalogSummary(
          selection: const VehicleCatalogSelection(
            modelYearId: 'year-1',
            brandName: 'VW - VolksWagen',
            modelName: 'AMAROK CD2.0 16V/S CD2.0 16V TDI 4x2 Die',
            modelYear: 2017,
          ),
          onChange: () {},
          onClear: () {},
        ),
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('VehicleCatalogPrompt', () {
    testWidgets('offers the picker and says typing by hand still works', (
      tester,
    ) async {
      var opened = 0;
      await pump(tester, VehicleCatalogPrompt(onPressed: () => opened++));

      expect(find.text('Escolher na tabela FIPE'), findsOneWidget);
      expect(find.textContaining('digitar à mão'), findsOneWidget);
      await tester.tap(find.text('Escolher na tabela FIPE'));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('an already-linked vehicle says so instead of implying it '
        'was typed by hand', (tester) async {
      await pump(
        tester,
        VehicleCatalogPrompt(onPressed: () {}, alreadyLinked: true),
      );

      expect(find.text('Trocar na tabela FIPE'), findsOneWidget);
      expect(find.textContaining('Veio da tabela FIPE'), findsOneWidget);
    });

    testWidgets('does nothing while the form is submitting', (tester) async {
      var opened = 0;
      await pump(
        tester,
        VehicleCatalogPrompt(onPressed: () => opened++, enabled: false),
      );

      await tester.tap(find.text('Escolher na tabela FIPE'));
      await tester.pump();
      expect(opened, 0);
    });
  });
}
