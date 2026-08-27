import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/presentation/cuidados_screen.dart';

void main() {
  testWidgets('a dimension that came back null never renders as zero', (
    tester,
  ) async {
    await _pump(tester, [
      _plan(
        name: 'Calibrar os pneus',
        slug: 'calibrar_pneus',
        kind: MaintenanceItemKind.care,
        status: MaintenanceStatus.venceEmBreve,
        remainingDays: 8,
      ),
    ]);

    expect(find.text('Calibrar os pneus'), findsOneWidget);
    expect(find.text('Está na hora de verificar.'), findsOneWidget);
    expect(find.text('faltam 8 dias'), findsNothing);
    expect(find.text('0 km'), findsNothing);
    expect(find.text('aos 0 km'), findsNothing);
    expect(find.text('a cada 0 km'), findsNothing);
    expect(find.text('vence agora'), findsNothing);
  });

  testWidgets('empty groups are omitted, care sits apart from maintenance', (
    tester,
  ) async {
    await _pump(tester, [
      _plan(
        name: 'Troca de óleo do motor',
        slug: 'troca_oleo',
        status: MaintenanceStatus.semBaseline,
      ),
      _plan(
        name: 'Lavar o carro',
        slug: 'lavar_carro',
        kind: MaintenanceItemKind.care,
        status: MaintenanceStatus.semBaseline,
      ),
    ]);

    expect(find.text('Precisam de atenção'), findsNothing);
    expect(find.text('Vencem em breve'), findsNothing);
    expect(find.text('Em dia'), findsNothing);
    expect(find.text('Só histórico'), findsNothing);
    expect(find.text('Falta informar'), findsOneWidget);
    expect(find.text('Cuidados do dia a dia'), findsOneWidget);
    expect(find.text('Troca de óleo do motor'), findsOneWidget);
    expect(find.text('Lavar o carro'), findsOneWidget);
    expect(
      find.text('Informe a última vez para começarmos a contar'),
      findsOneWidget,
    );
    expect(find.text('Está na hora de verificar.'), findsOneWidget);
  });

  testWidgets('the Falta informar group starts the calibrar action', (
    tester,
  ) async {
    var group = 0;
    var registered = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CuidadosContent(
            plans: [
              _plan(
                name: 'Troca de óleo do motor',
                slug: 'troca_oleo',
                status: MaintenanceStatus.semBaseline,
              ),
            ],
            onBaselineTap: (_) => registered++,
            onNeedsBaselineGroupTap: () => group++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Informar'));
    await tester.pump();

    expect(group, 1);
    expect(registered, 0);
  });

  testWidgets('sem_baseline opens the register action, not the detail', (
    tester,
  ) async {
    var registered = 0;
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CuidadosContent(
            plans: [
              _plan(
                name: 'Troca de óleo do motor',
                slug: 'troca_oleo',
                status: MaintenanceStatus.semBaseline,
              ),
            ],
            onPlanTap: (_) => opened++,
            onBaselineTap: (_) => registered++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Troca de óleo do motor'));
    await tester.pump();

    expect(registered, 1);
    expect(opened, 0);
  });

  group('360x640 with the font turned up', () {
    for (final theme in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      testWidgets('a full cuidados list lays out in ${theme.key}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 640) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme.value,
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.3),
                size: Size(360, 640),
              ),
              child: Scaffold(
                body: CuidadosContent(
                  plans: [
                    _plan(
                      name: 'Correia dentada',
                      slug: 'correia_dentada',
                      status: MaintenanceStatus.vencido,
                      remainingKm: -1200,
                      remainingDays: -40,
                    ),
                    _plan(
                      name: 'Alinhamento e balanceamento',
                      slug: 'alinhamento',
                      status: MaintenanceStatus.venceEmBreve,
                      remainingKm: 400,
                      remainingDays: 8,
                    ),
                    _plan(
                      name: 'Calibrar os pneus',
                      slug: 'calibrar_pneus',
                      kind: MaintenanceItemKind.care,
                      status: MaintenanceStatus.emDia,
                      remainingDays: 12,
                    ),
                    _plan(
                      name: 'Troca de óleo do motor',
                      slug: 'troca_oleo',
                      status: MaintenanceStatus.semBaseline,
                    ),
                    _plan(
                      name: 'Velas de ignição',
                      slug: 'velas',
                      status: MaintenanceStatus.emDia,
                      remainingKm: 8000,
                    ),
                    _plan(
                      name: 'Manutenção personalizada',
                      slug: 'personalizada',
                      status: MaintenanceStatus.semPeriodicidade,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }
  });

  // The two "no baseline" states are not the same thing on screen. One still
  // asks; the other has already been answered and is put away.
  testWidgets('an answered item moves out of the group that still asks', (
    tester,
  ) async {
    await _pump(tester, [
      _plan(
        name: 'Fluido de freio',
        slug: 'fluido_freio',
        status: MaintenanceStatus.semBaseline,
      ),
      _plan(
        name: 'Velas de ignição',
        slug: 'velas',
        status: MaintenanceStatus.semBaseline,
        historyStatus: MaintenanceHistoryStatus.unknown,
      ),
    ]);

    expect(find.text('Falta informar'), findsOneWidget);
    expect(find.text('Ainda sem registro'), findsOneWidget);
    expect(find.text('Fluido de freio'), findsOneWidget);
    // Collapsed, so the answered one is out of the way rather than gone.
    expect(find.text('Velas de ignição'), findsNothing);
  });

  testWidgets('an item the vehicle does not have is not rendered at all', (
    tester,
  ) async {
    await _pump(tester, [
      _plan(
        name: 'Correia dentada',
        slug: 'correia_dentada',
        status: MaintenanceStatus.naoSeAplica,
        strategy: MaintenanceStrategy.notApplicable,
      ),
      _plan(
        name: 'Pneus',
        slug: 'pneus',
        status: MaintenanceStatus.emDia,
        strategy: MaintenanceStrategy.conditionBased,
      ),
    ]);

    expect(find.text('Correia dentada'), findsNothing);
    expect(find.text('Não usa'), findsNothing);
    expect(find.text('Em dia'), findsOneWidget);
  });

  testWidgets('a condition-based item is not called overdue', (tester) async {
    await _pump(tester, [
      _plan(
        name: 'Pneus',
        slug: 'pneus',
        status: MaintenanceStatus.vencido,
        strategy: MaintenanceStrategy.conditionBased,
        remainingKm: -3000,
      ),
    ]);

    expect(find.text('Já rodou bastante — vale checar'), findsOneWidget);
    expect(find.text('Está vencida'), findsNothing);
  });

  group('Feito on a care card', () {
    testWidgets('shows on a care that asks for action', (tester) async {
      await _pump(tester, [
        _plan(
          name: 'Calibrar os pneus',
          slug: 'calibrar_pneus',
          kind: MaintenanceItemKind.care,
          status: MaintenanceStatus.vencido,
        ),
      ]);

      expect(find.text('Feito'), findsOneWidget);
      expect(find.text('Está na hora de verificar.'), findsOneWidget);
    });

    testWidgets('shows for due-soon and sem_baseline care', (tester) async {
      await _pump(tester, [
        _plan(
          name: 'Calibrar os pneus',
          slug: 'calibrar_pneus',
          kind: MaintenanceItemKind.care,
          status: MaintenanceStatus.venceEmBreve,
          remainingDays: 4,
        ),
        _plan(
          name: 'Lavar o carro',
          slug: 'lavar_carro',
          kind: MaintenanceItemKind.care,
          status: MaintenanceStatus.semBaseline,
        ),
      ]);

      expect(find.text('Feito'), findsNWidgets(2));
    });

    testWidgets('does not show on maintenance, even when overdue', (
      tester,
    ) async {
      await _pump(tester, [
        _plan(
          name: 'Troca de óleo do motor',
          slug: 'troca_oleo',
          status: MaintenanceStatus.vencido,
          remainingKm: -1200,
        ),
      ]);

      expect(find.text('Feito'), findsNothing);
    });

    testWidgets('does not show on a care that is already on track', (
      tester,
    ) async {
      await _pump(tester, [
        _plan(
          name: 'Calibrar os pneus',
          slug: 'calibrar_pneus',
          kind: MaintenanceItemKind.care,
          status: MaintenanceStatus.emDia,
          remainingDays: 12,
          lastOccurredOn: const CivilDate(2026, 7, 15),
          dueOn: const CivilDate(2026, 9, 11),
        ),
      ]);

      expect(find.text('Feito'), findsNothing);
      expect(find.text('Tudo certo'), findsOneWidget);
      expect(find.text('Última verificação'), findsOneWidget);
      expect(find.text('15 de julho de 2026'), findsOneWidget);
      expect(find.text('Próxima'), findsOneWidget);
      expect(find.text('11 de setembro de 2026'), findsOneWidget);
    });

    testWidgets('just recorded shows today and the server remaining days', (
      tester,
    ) async {
      await _pump(
        tester,
        [
          _plan(
            name: 'Calibrar os pneus',
            slug: 'calibrar_pneus',
            kind: MaintenanceItemKind.care,
            status: MaintenanceStatus.emDia,
            remainingDays: 15,
          ),
        ],
        justRecordedIds: {'plan-calibrar_pneus'},
      );

      expect(find.text('Registrado hoje'), findsOneWidget);
      expect(find.text('Próxima verificação em 15 dias'), findsOneWidget);
      expect(find.text('Feito'), findsNothing);
    });

    testWidgets('just recorded without remaining days shows only the first line', (
      tester,
    ) async {
      await _pump(
        tester,
        [
          _plan(
            name: 'Calibrar os pneus',
            slug: 'calibrar_pneus',
            kind: MaintenanceItemKind.care,
            status: MaintenanceStatus.emDia,
          ),
        ],
        justRecordedIds: {'plan-calibrar_pneus'},
      );

      expect(find.text('Registrado hoje'), findsOneWidget);
      expect(find.textContaining('Próxima verificação'), findsNothing);
    });

    testWidgets('tapping Feito does not open the card', (tester) async {
      var opened = 0;
      var marked = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CuidadosContent(
              plans: [
                _plan(
                  name: 'Calibrar os pneus',
                  slug: 'calibrar_pneus',
                  kind: MaintenanceItemKind.care,
                  status: MaintenanceStatus.vencido,
                ),
              ],
              onPlanTap: (_) => opened++,
              onMarkDone: (_) async => marked++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Feito'));
      await tester.pump();

      expect(marked, 1);
      expect(opened, 0);
    });

    testWidgets('the button is blocked while the write is in flight', (
      tester,
    ) async {
      await _pump(
        tester,
        [
          _plan(
            name: 'Calibrar os pneus',
            slug: 'calibrar_pneus',
            kind: MaintenanceItemKind.care,
            status: MaintenanceStatus.vencido,
          ),
        ],
        submittingIds: {'plan-calibrar_pneus'},
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Feito'),
      );
      expect(button.onPressed, isNull);
    });
  });

  testWidgets('an empty everyday-care section says everything is on track', (
    tester,
  ) async {
    await _pump(tester, [
      _plan(
        name: 'Troca de óleo do motor',
        slug: 'troca_oleo',
        status: MaintenanceStatus.emDia,
        remainingKm: 8000,
      ),
    ]);

    expect(find.text('Cuidados do dia a dia'), findsOneWidget);
    expect(find.text('Tudo em dia'), findsOneWidget);
    expect(
      find.text('Nenhum cuidado precisa da sua atenção agora.'),
      findsOneWidget,
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  List<MaintenancePlan> plans, {
  Set<String> justRecordedIds = const {},
  Set<String> submittingIds = const {},
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CuidadosContent(
          plans: plans,
          justRecordedIds: justRecordedIds,
          submittingIds: submittingIds,
          onMarkDone: (_) async {},
        ),
      ),
    ),
  );
}

MaintenancePlan _plan({
  required String name,
  required String slug,
  required MaintenanceStatus status,
  MaintenanceItemKind kind = MaintenanceItemKind.maintenance,
  MaintenanceStrategy strategy = MaintenanceStrategy.periodic,
  MaintenanceHistoryStatus historyStatus = MaintenanceHistoryStatus.notAsked,
  int? remainingKm,
  int? remainingDays,
  CivilDate? lastOccurredOn,
  CivilDate? dueOn,
}) {
  return MaintenancePlan(
    id: 'plan-$slug',
    maintenanceItemId: 'item-$slug',
    itemSlug: slug,
    itemName: name,
    itemKind: kind,
    alertKm: 500,
    alertDays: 15,
    origin: MaintenancePlanOrigin.suggested,
    strategy: strategy,
    historyStatus: historyStatus,
    status: status,
    remainingKm: remainingKm,
    remainingDays: remainingDays,
    lastOccurredOn: lastOccurredOn,
    dueOn: dueOn,
  );
}
