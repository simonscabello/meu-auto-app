import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/costs/presentation/costs_screen.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';

void main() {
  testWidgets('the headline is tracked_cents, not a client sum', (
    tester,
  ) async {
    await _pump(
      tester,
      _costs(
        maintenanceCents: 10000,
        obligationsCents: 10000,
        seguroCents: 10000,
        trackedCents: 5000,
      ),
    );

    expect(find.text('Custo registrado'), findsOneWidget);
    expect(find.text('3 meses'), findsOneWidget);
    expect(find.text('6 meses'), findsOneWidget);
    expect(find.text('12 meses'), findsOneWidget);
    expect(find.text('24 meses'), findsOneWidget);
    expect(find.text(r'R$ 50,00'), findsOneWidget);
    expect(find.text(r'R$ 300,00'), findsNothing);
    expect(find.textContaining('custo total'), findsNothing);
    expect(find.textContaining('gasto do mês'), findsNothing);
    expect(find.textContaining('este mês'), findsNothing);
  });

  testWidgets('a period with no entries shows zero, not an error', (
    tester,
  ) async {
    await _pump(tester, _costs(periodMonths: 6));

    expect(find.text('Custo registrado'), findsOneWidget);
    expect(find.text(r'R$ 0,00'), findsWidgets);
    expect(
      find.text(
        'Nenhum custo nos últimos 6 meses. Troque o intervalo ou registre um serviço.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('names what the figure leaves out', (tester) async {
    await _pump(tester, _costs(trackedCents: 154000));

    expect(
      find.text(
        'Combustível e despesas do dia a dia ainda não entram nesta conta.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('lays out on 360x640 with the font turned up', (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.3),
            size: Size(360, 640),
          ),
          child: Scaffold(
            body: CostsContent(
              costs: _costs(trackedCents: 154000, periodMonths: 12),
              selectedMonths: 12,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, DashboardCosts costs) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CostsContent(costs: costs, selectedMonths: costs.periodMonths),
      ),
    ),
  );
}

DashboardCosts _costs({
  int periodMonths = 12,
  int maintenanceCents = 0,
  int obligationsCents = 0,
  int seguroCents = 0,
  int trackedCents = 0,
}) {
  return DashboardCosts(
    periodMonths: periodMonths,
    since: const CivilDate(2025, 8, 26),
    maintenanceCents: Money.fromCents(maintenanceCents),
    obligationsCents: Money.fromCents(obligationsCents),
    seguroCents: Money.fromCents(seguroCents),
    trackedCents: Money.fromCents(trackedCents),
    trackedCategories: const ['manutencao', 'ipva', 'licenciamento', 'seguro'],
  );
}
