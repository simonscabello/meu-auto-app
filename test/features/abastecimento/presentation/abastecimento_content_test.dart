import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_detail_screen.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_list_screen.dart';
import 'package:meu_auto/features/abastecimento/presentation/last_abastecimento_card.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';

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

  testWidgets('each consumption status has its own phrase and no invented km/L', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AbastecimentoListContent(
            state: PagedState(
              items: [
                _fill(
                  id: 'ok',
                  status: ConsumptionStatus.ok,
                  value: 17.82,
                ),
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

    expect(find.text('17,8 km/L'), findsOneWidget);
    expect(
      find.text(
        'Abastecimento parcial — o consumo entra no próximo tanque cheio.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Consumo disponível a partir do próximo tanque cheio.'),
      findsOneWidget,
    );
    expect(
      find.text('Não foi possível calcular o consumo deste registro.'),
      findsNWidgets(2),
    );
    expect(find.textContaining('17,82'), findsNothing);
  });

  testWidgets('delete confirmation cites the odometer reading', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: AbastecimentoDetailContent(
                fill: _fill(),
                onDelete: () async {
                  final confirmed = await confirmAction(
                    context,
                    title: abastecimentoDeleteTitle,
                    message: abastecimentoDeleteMessage,
                    confirmLabel: 'Excluir',
                    destructive: true,
                  );
                  if (confirmed) deleted++;
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(abastecimentoDeleteTitle), findsOneWidget);
    expect(find.text(abastecimentoDeleteMessage), findsOneWidget);
    expect(deleted, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('an electric vehicle hides the dashboard card', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LastAbastecimentoCard(supported: false),
        ),
      ),
    );

    expect(find.text(abastecimentoEmptyTitle), findsNothing);
    expect(find.text(abastecimentoRegisterLabel), findsNothing);
    expect(find.text('Último abastecimento'), findsNothing);
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
