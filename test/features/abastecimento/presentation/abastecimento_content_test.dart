import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/abastecimento/application/abastecimento_provider.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_detail_screen.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_list_screen.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  testWidgets('the empty list uses the register copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AbastecimentoListContent(
            state: const PagedState(hasMore: false),
            onRegister: () {},
          ),
        ),
      ),
    );

    expect(find.text(abastecimentoEmptyTitle), findsOneWidget);
    expect(find.text(abastecimentoEmptyMessage), findsOneWidget);
    expect(find.text(abastecimentoRegisterLabel), findsOneWidget);
  });

  testWidgets(
    'each consumption status has its own clause and no invented km/L',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AbastecimentoListContent(
              state: PagedState(
                items: [
                  _fill(id: 'ok', status: ConsumptionStatus.ok, value: 17.82),
                  _fill(id: 'partial', status: ConsumptionStatus.partialFill),
                  _fill(
                    id: 'first',
                    status: ConsumptionStatus.insufficientData,
                  ),
                  _fill(id: 'unavail', status: ConsumptionStatus.unavailable),
                  _fill(id: 'unknown', status: ConsumptionStatus.desconhecido),
                ],
                hasMore: false,
              ),
            ),
          ),
        ),
      );

      // The row carries the date and, when there is one, a short clause; the
      // full sentence lives on the fill's own screen.
      expect(find.text('10 ago · 17,8 km/L'), findsOneWidget);
      expect(find.text('10 ago · Tanque parcial'), findsOneWidget);
      expect(find.text('10 ago · Sem consumo ainda'), findsOneWidget);
      // Unavailable and unknown have nothing worth a clause: the date alone.
      expect(find.text('10 ago'), findsNWidgets(2));
      expect(find.textContaining('17,82'), findsNothing);
    },
  );

  testWidgets('deleting from the ⋮ asks first and cites the odometer', (
    tester,
  ) async {
    const id = 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          abastecimentoProvider(id).overrideWith((ref) async => _fill(id: id)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AbastecimentoDetailScreen(abastecimentoId: id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing destructive on the page itself: it is inside the menu.
    expect(find.text('Excluir abastecimento'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir abastecimento'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(abastecimentoDeleteTitle), findsOneWidget);
    expect(find.text(abastecimentoDeleteMessage), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AbastecimentoDetailContent), findsOneWidget);
  });

  testWidgets('detail shows the server price per litre, never a typed one', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: AbastecimentoDetailContent(fill: _fill())),
      ),
    );

    expect(find.text('Preço por litro'), findsOneWidget);
    expect(find.text('R\$ 6,87'), findsOneWidget);
  });
}

Abastecimento _fill({
  String id = 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb',
  ConsumptionStatus status = ConsumptionStatus.ok,
  double? value = 17.82,
}) {
  return Abastecimento(
    id: id,
    vehicleId: 'v1',
    occurredOn: const CivilDate(2026, 8, 10),
    mileageKm: 96420,
    volumeMl: 34700,
    totalCostCents: const Money.fromCents(23840),
    pricePerLiterCents: const Money.fromCents(687),
    fuel: AbastecimentoFuel.gasolina,
    fullTank: true,
    consumption: Consumption(
      value: status == ConsumptionStatus.ok ? value : null,
      unit: 'km_per_liter',
      status: status,
    ),
    createdAt: DateTime.utc(2026, 8, 10),
    updatedAt: DateTime.utc(2026, 8, 10),
  );
}
