import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/presentation/last_abastecimento_card.dart';
import 'package:meu_auto/shared/widgets/app_metric.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  testWidgets('ok consumption shows amount, litres and km/L', (tester) async {
    await _pump(tester, last: _last());

    expect(find.text('Último abastecimento'), findsOneWidget);
    expect(find.text('10 de agosto'), findsOneWidget);
    expect(find.byType(AppMetric), findsNWidgets(3));
    expect(find.text(r'R$ 238,40'), findsOneWidget);
    expect(find.text('34,7 L'), findsOneWidget);
    expect(find.text('17,8 km/L'), findsOneWidget);
    expect(find.textContaining('Preço por litro'), findsNothing);
  });

  testWidgets('insufficient_data keeps amount and litres and uses the status phrase', (
    tester,
  ) async {
    await _pump(
      tester,
      last: _last(
        consumption: const Consumption(
          unit: 'km_per_liter',
          status: ConsumptionStatus.insufficientData,
        ),
      ),
    );

    expect(find.text('Último abastecimento'), findsOneWidget);
    expect(find.text(r'R$ 238,40'), findsOneWidget);
    expect(find.text('34,7 L'), findsOneWidget);
    expect(find.byType(AppMetric), findsNWidgets(2));
    expect(
      find.text('Consumo disponível a partir do próximo tanque cheio.'),
      findsOneWidget,
    );
    expect(find.textContaining('km/L'), findsNothing);
  });

  testWidgets('no fill is a discreet invite, not the list empty state', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Registre o primeiro abastecimento'), findsOneWidget);
    expect(find.text('Último abastecimento'), findsNothing);
    expect(find.text(abastecimentoEmptyTitle), findsNothing);
    expect(find.text(abastecimentoEmptyMessage), findsNothing);
    expect(find.text(abastecimentoRegisterLabel), findsNothing);
  });

  testWidgets('an unsupported vehicle hides the block entirely', (tester) async {
    await _pump(tester, supported: false, last: _last());

    expect(find.text('Último abastecimento'), findsNothing);
    expect(find.text('Registre o primeiro abastecimento'), findsNothing);
    expect(find.byType(AppMetric), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  bool supported = true,
  LastAbastecimento? last,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: LastAbastecimentoCard(supported: supported, last: last),
      ),
    ),
  );
}

LastAbastecimento _last({
  Consumption consumption = const Consumption(
    value: 17.82,
    unit: 'km_per_liter',
    status: ConsumptionStatus.ok,
  ),
}) {
  return LastAbastecimento(
    id: 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb',
    occurredOn: const CivilDate(2026, 8, 10),
    totalCostCents: const Money.fromCents(23840),
    volumeMl: 34700,
    pricePerLiterCents: const Money.fromCents(687),
    fuel: AbastecimentoFuel.gasolina,
    consumption: consumption,
  );
}
