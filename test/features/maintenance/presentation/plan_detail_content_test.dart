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

    expect(find.text('a cada 12 meses'), findsOneWidget);
    expect(find.text('0 km'), findsNothing);
    expect(find.text('aos 0 km'), findsNothing);
    expect(find.text('a cada 0 km'), findsNothing);
    expect(find.text('em 10/08/2027'), findsOneWidget);
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
    expect(find.text('Você não lembra — tudo bem'), findsOneWidget);
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

  testWidgets('"meu carro não usa isso" is offered as a correction', (
    tester,
  ) async {
    var tapped = false;
    await _pump(tester, _plan(), onNotApplicable: () => tapped = true);

    await tester.tap(find.text('Meu carro não usa isso'));
    await tester.pump();

    expect(tapped, isTrue);
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
  VoidCallback? onNotApplicable,
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
            onNotApplicable: onNotApplicable,
          ),
        ),
      ),
    ),
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
  );
}

MaintenanceRecord _record({
  required String id,
  required CivilDate on,
  required int km,
}) {
  return MaintenanceRecord(
    id: id,
    vehicleId: 'v1',
    occurredOn: on,
    mileageKm: km,
    kind: MaintenanceRecordKind.performed,
    totalCostCents: Money.zero,
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
