import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_detail_screen.dart';
import 'package:meu_auto/core/domain/money.dart';

void main() {
  testWidgets('a null due dimension is omitted, never written as zero', (
    tester,
  ) async {
    await _pump(
      tester,
      _plan(
        intervalMonths: 12,
        dueOn: const CivilDate(2027, 8, 10),
        remainingDays: 349,
      ),
    );

    expect(find.text('A cada 12 meses'), findsOneWidget);
    expect(find.textContaining('0 km'), findsNothing);
    // One dimension is not a strip: the date is a line of the details.
    expect(find.text('10/08/2027'), findsOneWidget);
    expect(find.text('Vence em 10/08/2027'), findsOneWidget);
  });

  // The same words Início uses for the same item, beside the badge.
  testWidgets('the header says how far, and the strip says when', (
    tester,
  ) async {
    await _pump(
      tester,
      _plan(
        intervalKm: 10000,
        intervalMonths: 12,
        dueAtKm: 141011,
        dueOn: const CivilDate(2027, 3, 21),
        remainingKm: 2000,
        remainingDays: 177,
        lastOccurredOn: const CivilDate(2026, 3, 21),
        lastMileageKm: 131011,
      ),
    );

    expect(find.text('Troca de óleo do motor'), findsOneWidget);
    expect(find.text('Em dia'), findsOneWidget);
    expect(find.text('Faltam 2.000 km ou até 21/03/2027'), findsOneWidget);
    expect(find.text('Última vez'), findsOneWidget);
    expect(find.text('21/03/2026'), findsOneWidget);
    expect(find.text('Próxima'), findsOneWidget);
    expect(find.text('141.011 km'), findsOneWidget);
    expect(find.text('Ou em'), findsOneWidget);
    expect(find.text('21/03/2027'), findsOneWidget);
    expect(find.text('A cada 10.000 km ou 12 meses'), findsOneWidget);
  });

  testWidgets('a late item says by how much, in the closer dimension', (
    tester,
  ) async {
    await _pump(
      tester,
      _plan(
        status: MaintenanceStatus.vencido,
        intervalKm: 10000,
        dueAtKm: 137011,
        remainingKm: -2000,
        remainingDays: 40,
        dueOn: const CivilDate(2026, 11, 4),
        lastOccurredOn: const CivilDate(2025, 11, 4),
        lastMileageKm: 127011,
      ),
    );

    expect(find.text('Vencido'), findsOneWidget);
    expect(find.text('Passou 2.000 km'), findsOneWidget);
  });

  // A tyre that has run its suggested distance is "vencido" on the wire and
  // is not a deadline: the badge says so in its own words.
  testWidgets('a condition-based item is worth checking, not late', (
    tester,
  ) async {
    await _pump(
      tester,
      _plan(
        status: MaintenanceStatus.vencido,
        strategy: MaintenanceStrategy.conditionBased,
        intervalKm: 50000,
        remainingKm: -500,
      ),
    );

    expect(find.text('Vale checar'), findsOneWidget);
    expect(find.text('Vencido'), findsNothing);
  });

  group('the one action', () {
    testWidgets('a service registers the service', (tester) async {
      await _pump(
        tester,
        _plan(intervalKm: 10000, dueAtKm: 141011, remainingKm: 2000),
        onRegister: () {},
      );

      expect(find.text('Registrar manutenção'), findsOneWidget);
      expect(find.text('Marcar como feito'), findsNothing);
    });

    testWidgets('a care habit is marked done, in one tap', (tester) async {
      var done = 0;
      await _pump(
        tester,
        _care(status: MaintenanceStatus.vencido, remainingDays: -13),
        onRegister: () {},
        onMarkDone: () => done++,
      );

      expect(find.text('Venceu há 13 dias'), findsOneWidget);
      expect(find.text('Registrar manutenção'), findsNothing);
      await tester.tap(find.text('Marcar como feito'));
      expect(done, 1);
    });

    testWidgets('marking done does not take a second tap in flight', (
      tester,
    ) async {
      var done = 0;
      await _pump(
        tester,
        _care(status: MaintenanceStatus.vencido, remainingDays: -13),
        onMarkDone: () => done++,
        markingDone: true,
      );

      await tester.tap(find.byType(FilledButton));
      expect(done, 0);
    });
  });

  testWidgets('a history line shows what this item cost on that visit', (
    tester,
  ) async {
    await _pump(
      tester,
      _plan(
        lastOccurredOn: const CivilDate(2026, 8, 10),
        lastMileageKm: 108200,
      ),
      history: [
        _record(
          id: 'r1',
          on: const CivilDate(2026, 8, 10),
          km: 108200,
          total: 18000,
        ),
      ],
    );

    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('10 de agosto de 2026'), findsOneWidget);
    expect(find.text('R\$ 180,00'), findsOneWidget);
  });

  testWidgets('no history says so under the group', (tester) async {
    await _pump(tester, _plan(intervalKm: 10000));

    expect(find.text('Nenhum registro deste item ainda.'), findsOneWidget);
  });

  testWidgets('history shows the mileage delta between two records', (
    tester,
  ) async {
    await _pump(
      tester,
      _plan(
        lastOccurredOn: const CivilDate(2026, 8, 10),
        lastMileageKm: 108200,
      ),
      history: [
        _record(id: 'r1', on: const CivilDate(2026, 8, 10), km: 108200),
        _record(id: 'r2', on: const CivilDate(2025, 8, 10), km: 98200),
      ],
    );

    expect(find.textContaining('10.000 km desde a anterior'), findsOneWidget);
  });

  group('360x640 with the font turned up', () {
    for (final theme in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      testWidgets('plan detail lays out in ${theme.key}', (tester) async {
        tester.view.physicalSize = const Size(360, 640) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pump(
          tester,
          _plan(
            origin: MaintenancePlanOrigin.suggested,
            intervalKm: 10000,
            intervalMonths: 12,
            dueAtKm: 108200,
            dueOn: const CivilDate(2027, 8, 10),
            remainingKm: 1550,
            remainingDays: 349,
            lastOccurredOn: const CivilDate(2026, 8, 10),
            lastMileageKm: 98200,
          ),
          theme: theme.value,
          scale: 1.3,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  // The two answers about the past are offered only while there is nothing to
  // measure from. Once a service is recorded, the record IS the answer, and
  // asking again would invite contradicting it.
  testWidgets('the history answers appear only when there is no baseline', (
    tester,
  ) async {
    await _pump(
      tester,
      _plan(status: MaintenanceStatus.semBaseline),
      onHistoryUnknown: (_) {},
    );
    expect(find.text('Não sei quando foi'), findsOneWidget);
    expect(find.text('Nunca foi feito'), findsOneWidget);

    await _pump(
      tester,
      _plan(status: MaintenanceStatus.emDia),
      onHistoryUnknown: (_) {},
    );
    expect(find.text('Não sei quando foi'), findsNothing);
    expect(find.text('Nunca foi feito'), findsNothing);
  });

  testWidgets('an answer already given is not asked again', (tester) async {
    await _pump(
      tester,
      _plan(
        status: MaintenanceStatus.semBaseline,
        historyStatus: MaintenanceHistoryStatus.unknown,
      ),
      onHistoryUnknown: (_) {},
    );

    expect(find.text('Não sei quando foi'), findsNothing);
    expect(find.text('Você não lembra quando foi'), findsWidgets);
  });

  testWidgets('each history answer reports itself, and writes no record', (
    tester,
  ) async {
    final answered = <MaintenanceHistoryStatus>[];
    await _pump(
      tester,
      _plan(status: MaintenanceStatus.semBaseline),
      onHistoryUnknown: answered.add,
    );

    await tester.tap(find.text('Não sei quando foi'));
    await tester.tap(find.text('Nunca foi feito'));
    await tester.pump();

    expect(answered, [
      MaintenanceHistoryStatus.unknown,
      MaintenanceHistoryStatus.never,
    ]);
  });

  // The rarer choices live in the app bar menu, out of the way of the two
  // things someone opens this screen to do.
  testWidgets('"meu carro não tem isso" is offered in the menu', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(
            actions: [
              PlanDetailMenu(
                onNotApplicable: () => tapped = true,
                onDeactivate: () {},
              ),
            ],
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    expect(find.text('Parar de acompanhar'), findsOneWidget);
    await tester.tap(find.text('Meu carro não tem isso'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  // "Nunca foi feito" counts from the car being new; the screen says so where
  // the last service would be, instead of a 0 km visit that never happened.
  testWidgets('a since-new baseline is explained, not shown as a service', (
    tester,
  ) async {
    await _pump(
      tester,
      _plan(
        status: MaintenanceStatus.vencido,
        historyStatus: MaintenanceHistoryStatus.never,
        baseline: MaintenanceBaseline.sinceNew,
        intervalKm: 60000,
      ),
      onRegister: () {},
    );

    expect(
      find.text(
        'Nunca foi feito — contamos a partir de quando o carro era novo',
      ),
      findsOneWidget,
    );
    expect(find.text('Informar a última vez'), findsNothing);
    expect(find.text('Registrar manutenção'), findsOneWidget);
  });

  // A condition-based item explains itself, because "a cada 50.000 km" on a
  // tyre reads as a deadline and is not one.
  testWidgets('a condition-based item says the interval is only a reminder', (
    tester,
  ) async {
    await _pump(
      tester,
      _plan(strategy: MaintenanceStrategy.conditionBased, intervalKm: 50000),
    );

    expect(find.textContaining('depende do desgaste'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  MaintenancePlan plan, {
  List<MaintenanceRecord> history = const [],
  ThemeData? theme,
  double scale = 1.0,
  ValueChanged<MaintenanceHistoryStatus>? onHistoryUnknown,
  VoidCallback? onRegister,
  VoidCallback? onMarkDone,
  bool markingDone = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: PlanDetailContent(
            plan: plan,
            history: history,
            onHistoryUnknown: onHistoryUnknown,
            onRegister: onRegister,
            onMarkDone: onMarkDone,
            markingDone: markingDone,
          ),
        ),
      ),
    ),
  );
}

MaintenancePlan _care({
  MaintenanceStatus status = MaintenanceStatus.emDia,
  int? remainingDays,
}) {
  return MaintenancePlan(
    id: 'plan-care',
    maintenanceItemId: 'item-care',
    itemSlug: 'calibrar_pneus',
    itemName: 'Calibrar os pneus',
    itemKind: MaintenanceItemKind.care,
    intervalDays: 15,
    alertKm: 500,
    alertDays: 5,
    origin: MaintenancePlanOrigin.suggested,
    strategy: MaintenanceStrategy.periodic,
    historyStatus: MaintenanceHistoryStatus.notAsked,
    status: status,
    remainingDays: remainingDays,
  );
}

MaintenancePlan _plan({
  MaintenancePlanOrigin origin = MaintenancePlanOrigin.user,
  MaintenanceStrategy strategy = MaintenanceStrategy.periodic,
  MaintenanceHistoryStatus historyStatus = MaintenanceHistoryStatus.notAsked,
  MaintenanceStatus status = MaintenanceStatus.emDia,
  int? intervalKm,
  int? intervalMonths,
  int? intervalDays,
  int? dueAtKm,
  CivilDate? dueOn,
  int? remainingKm,
  int? remainingDays,
  CivilDate? lastOccurredOn,
  int? lastMileageKm,
  MaintenanceBaseline baseline = MaintenanceBaseline.none,
}) {
  return MaintenancePlan(
    id: 'plan-1',
    maintenanceItemId: 'item-1',
    itemSlug: 'troca_oleo',
    itemName: 'Troca de óleo do motor',
    itemKind: MaintenanceItemKind.maintenance,
    intervalKm: intervalKm,
    intervalMonths: intervalMonths,
    intervalDays: intervalDays,
    alertKm: 1000,
    alertDays: 15,
    origin: origin,
    strategy: strategy,
    historyStatus: historyStatus,
    status: status,
    dueAtKm: dueAtKm,
    dueOn: dueOn,
    remainingKm: remainingKm,
    remainingDays: remainingDays,
    lastOccurredOn: lastOccurredOn,
    lastMileageKm: lastMileageKm,
    baseline: baseline,
  );
}

MaintenanceRecord _record({
  required String id,
  required CivilDate on,
  required int km,
  int total = 0,
}) {
  return MaintenanceRecord(
    id: id,
    vehicleId: 'v1',
    occurredOn: on,
    mileageKm: km,
    kind: MaintenanceRecordKind.performed,
    totalCostCents: Money.fromCents(total),
    items: const [
      MaintenanceRecordItem(
        id: 'line-1',
        maintenanceItemId: 'item-1',
        itemSlug: 'troca_oleo',
        itemName: 'Troca de óleo do motor',
      ),
    ],
    createdAt: DateTime(2026, 8, 10),
    updatedAt: DateTime(2026, 8, 10),
  );
}
