import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/presentation/care_periodicity_sheet.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_interval_sheet.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_periodicity.dart';

void main() {
  testWidgets('a care item opens CarePeriodicitySheet', (tester) async {
    await _open(tester, _plan(kind: MaintenanceItemKind.care));

    await tester.tap(find.text('Ajustar'));
    await tester.pumpAndSettle();

    expect(find.byType(CarePeriodicitySheet), findsOneWidget);
    expect(find.byType(PlanIntervalSheet), findsNothing);
  });

  testWidgets('a maintenance item opens PlanIntervalSheet', (tester) async {
    await _open(tester, _plan(kind: MaintenanceItemKind.maintenance));

    await tester.tap(find.text('Ajustar'));
    await tester.pumpAndSettle();

    expect(find.byType(PlanIntervalSheet), findsOneWidget);
    expect(find.byType(CarePeriodicitySheet), findsNothing);
  });
}

Future<void> _open(WidgetTester tester, MaintenancePlan plan) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
        maintenanceItemsProvider.overrideWith(
          (ref) async => [
            MaintenanceItem(
              id: plan.maintenanceItemId,
              slug: plan.itemSlug,
              name: plan.itemName,
              kind: plan.itemKind,
              vehicleType: 'car',
              isCustom: false,
              defaultStrategy: plan.strategy,
              defaultIntervalDays: 15,
            ),
          ],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPlanPeriodicitySheet(
                context,
                vehicleId: 'vehicle-1',
                plan: plan,
              ),
              child: const Text('Ajustar'),
            ),
          ),
        ),
      ),
    ),
  );
}

MaintenancePlan _plan({required MaintenanceItemKind kind}) {
  return MaintenancePlan(
    id: 'plan-1',
    maintenanceItemId: 'item-1',
    itemSlug: kind == MaintenanceItemKind.care ? 'calibrar_pneus' : 'troca_oleo',
    itemName: kind == MaintenanceItemKind.care
        ? 'Calibrar os pneus'
        : 'Troca de óleo do motor',
    itemKind: kind,
    intervalDays: kind == MaintenanceItemKind.care ? 15 : null,
    intervalKm: kind == MaintenanceItemKind.care ? null : 10000,
    alertKm: 500,
    alertDays: 15,
    origin: MaintenancePlanOrigin.suggested,
    strategy: MaintenanceStrategy.periodic,
    historyStatus: MaintenanceHistoryStatus.notAsked,
    status: MaintenanceStatus.emDia,
  );
}
