import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/dashboard/presentation/dashboard_screen.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

void main() {
  testWidgets('overdue count produces the critical status phrase', (
    tester,
  ) async {
    await _pump(tester, _dashboard(overdue: 2, dueSoon: 1, needsBaseline: 4));

    expect(find.text('2 itens precisam de atenção'), findsOneWidget);
    expect(find.text('1 item vence em breve'), findsNothing);
    expect(find.text('Falta informar o histórico'), findsNothing);
    expect(find.text('Tudo em dia'), findsNothing);
  });

  testWidgets(
    'due-soon count produces the warning phrase when nothing is overdue',
    (tester) async {
      await _pump(tester, _dashboard(overdue: 0, dueSoon: 3, needsBaseline: 4));

      expect(find.text('3 itens vencem em breve'), findsOneWidget);
      expect(find.text('Falta informar o histórico'), findsNothing);
      expect(find.text('Tudo em dia'), findsNothing);
    },
  );

  testWidgets('needs_baseline alone produces the invite phrase', (
    tester,
  ) async {
    await _pump(tester, _dashboard(overdue: 0, dueSoon: 0, needsBaseline: 18));

    expect(find.text('Falta informar o histórico'), findsOneWidget);
    expect(find.text('Tudo em dia'), findsNothing);
  });

  testWidgets('all-zero counts produce the on-track phrase', (tester) async {
    await _pump(tester, _dashboard(overdue: 0, dueSoon: 0, needsBaseline: 0));

    expect(find.text('Tudo em dia'), findsOneWidget);
    expect(find.text('Falta informar o histórico'), findsNothing);
  });

  testWidgets('setup card appears only when needs_baseline is above zero', (
    tester,
  ) async {
    await _pump(tester, _dashboard(overdue: 0, dueSoon: 0, needsBaseline: 18));
    expect(
      find.textContaining('18 itens ainda não têm histórico'),
      findsOneWidget,
    );
    expect(find.text('Configurar'), findsOneWidget);

    await _pump(tester, _dashboard(overdue: 2, dueSoon: 0, needsBaseline: 0));
    expect(find.textContaining('ainda não têm histórico'), findsNothing);
    expect(find.text('Configurar'), findsNothing);
  });

  testWidgets('cost card says registered cost and lists included categories', (
    tester,
  ) async {
    await _pump(tester, _dashboard(periodMonths: 12));

    expect(find.text('Custo registrado · últimos 12 meses'), findsOneWidget);
    expect(
      find.text('Inclui manutenção, IPVA, licenciamento e seguro'),
      findsOneWidget,
    );
    expect(find.textContaining('custo total'), findsNothing);
    expect(find.textContaining('Custo total'), findsNothing);
    expect(find.textContaining('este mês'), findsNothing);
  });

  testWidgets('a one-month cost window is labelled as the last 30 days', (
    tester,
  ) async {
    await _pump(tester, _dashboard(periodMonths: 1));

    expect(find.text('Custo registrado · últimos 30 dias'), findsOneWidget);
    expect(find.textContaining('este mês'), findsNothing);
  });

  testWidgets('the cost card is the entry into the costs screen', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DashboardContent(
            dashboard: _dashboard(),
            onCostsTap: () => opened = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Custo registrado · últimos 12 meses'));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('DashboardView shows a skeleton while loading', (tester) async {
    final pending = Completer<Dashboard>();
    addTearDown(() {
      if (!pending.isCompleted) {
        pending.complete(_dashboard());
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider(_vehicleId).overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DashboardView(vehicleId: _vehicleId)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSkeleton), findsWidgets);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('DashboardView shows a retryable offline error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider(
            _vehicleId,
          ).overrideWith((ref) async => throw const ApiFailure.semConexao()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DashboardView(vehicleId: _vehicleId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppErrorState.offlineTitle), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('DashboardView shows content when the dashboard loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider(
            _vehicleId,
          ).overrideWith((ref) async => _dashboard()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DashboardView(vehicleId: _vehicleId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tudo em dia'), findsOneWidget);
    expect(find.byType(AppErrorState), findsNothing);
  });

  test('an obligation alert opens the detail, not Cuidados', () {
    expect(
      routeForAlert(_alert(type: AlertReferenceType.obligation, id: 'ob-1')),
      AppRoutes.obligation('ob-1'),
    );
    expect(
      routeForAlert(_alert(type: AlertReferenceType.obligation, id: 'ob-1')),
      isNot(AppRoutes.care),
    );
  });

  test('a seguro alert opens the policy detail', () {
    expect(
      routeForAlert(_alert(type: AlertReferenceType.seguro, id: 'sg-1')),
      AppRoutes.seguro('sg-1'),
    );
  });
}

const _vehicleId = '11111111-1111-7111-8111-111111111111';

Future<void> _pump(WidgetTester tester, Dashboard dashboard) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: DashboardContent(dashboard: dashboard)),
    ),
  );
}

Dashboard _dashboard({
  int overdue = 0,
  int dueSoon = 0,
  int needsBaseline = 0,
  int periodMonths = 12,
  DashboardProfile profile = DashboardProfile.empty,
}) {
  return Dashboard(
    vehicle: const DashboardVehicle(
      id: '11111111-1111-7111-8111-111111111111',
      brand: 'Fiat',
      model: 'Argo',
      nickname: 'Argolino',
      plate: 'ABC1D23',
    ),
    odometer: const DashboardOdometer(
      currentKm: 48320,
      recordedOn: CivilDate(2026, 8, 10),
    ),
    alerts: DashboardAlerts(
      overdue: overdue,
      dueSoon: dueSoon,
      needsBaseline: needsBaseline,
      items: const [],
    ),
    profile: profile,
    costs: DashboardCosts(
      periodMonths: periodMonths,
      since: const CivilDate(2025, 8, 26),
      maintenanceCents: const Money.fromCents(0),
      obligationsCents: const Money.fromCents(0),
      seguroCents: const Money.fromCents(0),
      trackedCents: const Money.fromCents(154000),
      trackedCategories: const [
        'manutencao',
        'ipva',
        'licenciamento',
        'seguro',
      ],
    ),
  );
}

Alert _alert({required AlertReferenceType type, required String id}) {
  return Alert(
    kind: AlertKind.ipva,
    severity: AlertSeverity.venceEmBreve,
    title: 'IPVA',
    referenceType: type,
    referenceId: id,
  );
}
