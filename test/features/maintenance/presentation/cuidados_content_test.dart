import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('faltam 8 dias'), findsOneWidget);
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
      findsNWidgets(2),
    );
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
}

Future<void> _pump(WidgetTester tester, List<MaintenancePlan> plans) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: CuidadosContent(plans: plans)),
    ),
  );
}

MaintenancePlan _plan({
  required String name,
  required String slug,
  required MaintenanceStatus status,
  MaintenanceItemKind kind = MaintenanceItemKind.maintenance,
  int? remainingKm,
  int? remainingDays,
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
    status: status,
    remainingKm: remainingKm,
    remainingDays: remainingDays,
  );
}
