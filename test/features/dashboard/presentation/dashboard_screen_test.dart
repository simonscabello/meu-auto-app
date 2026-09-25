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
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

void main() {
  testWidgets('overdue count produces the critical status phrase', (
    tester,
  ) async {
    await _pump(tester, _dashboard(overdue: 2, dueSoon: 1, needsBaseline: 4));

    // The phrase counts only what it names; the one due soon is the quiet
    // line under it, not a second verdict.
    expect(find.text('2 itens vencidos'), findsOneWidget);
    expect(find.text('Mais 1 vence em breve'), findsOneWidget);
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

  // A car nobody told us about is not "em dia". It is not broken either: the
  // verdict is neutral — no status colour — and says what is missing.
  testWidgets('an unknown history is a neutral verdict, not "Tudo em dia"', (
    tester,
  ) async {
    await _pump(
      tester,
      _dashboard(overdue: 0, dueSoon: 0, needsBaseline: 11, unknownHistory: 16),
    );

    expect(find.text('Tudo em dia'), findsNothing);
    expect(find.text('Nada vencido até agora'), findsOneWidget);
    expect(find.text('16 itens sem data da última vez'), findsOneWidget);
  });

  // An owner who answered "não sei" to every question leaves needs_baseline at
  // zero. The verdict reads unknown_history, which still counts them.
  testWidgets('"não sei" everywhere is still unknown, not fine', (
    tester,
  ) async {
    await _pump(
      tester,
      _dashboard(overdue: 0, dueSoon: 0, needsBaseline: 0, unknownHistory: 5),
    );

    expect(find.text('Tudo em dia'), findsNothing);
    expect(find.text('5 itens sem data da última vez'), findsOneWidget);
  });

  // An older server sends no unknown_history; needs_baseline is the most the
  // app can say, and it says that rather than "Tudo em dia".
  testWidgets(
    'without unknown_history the verdict falls back to needs_baseline',
    (tester) async {
      await _pump(
        tester,
        _dashboard(overdue: 0, dueSoon: 0, needsBaseline: 18),
      );

      expect(find.text('Tudo em dia'), findsNothing);
      expect(find.text('18 itens sem data da última vez'), findsOneWidget);
    },
  );

  testWidgets('all-zero counts produce the on-track phrase', (tester) async {
    await _pump(
      tester,
      _dashboard(overdue: 0, dueSoon: 0, needsBaseline: 0, unknownHistory: 0),
    );

    expect(find.text('Tudo em dia'), findsOneWidget);
    expect(find.text('Falta informar o histórico'), findsNothing);
  });

  testWidgets('the overdue verdict still wins over an empty history', (
    tester,
  ) async {
    await _pump(tester, _dashboard(overdue: 2, dueSoon: 0, needsBaseline: 18));

    expect(find.text('2 itens vencidos'), findsOneWidget);
    expect(find.textContaining('vence em breve'), findsNothing);
    expect(find.textContaining('ainda não têm histórico'), findsNothing);
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
          maintenancePlansProvider(_vehicleId).overrideWith((ref) async => []),
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
          maintenancePlansProvider(_vehicleId).overrideWith((ref) async => []),
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
          maintenancePlansProvider(_vehicleId).overrideWith((ref) async => []),
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

  // Registering a fill or a service is the most common reason to open the app,
  // and it used to take a tab change and an app-bar icon to reach. These are
  // named actions on the one screen where all of them are plausible — not the
  // global "+" that was removed, which could not say what it would do.
  group('quick actions', () {
    testWidgets('names each action, and routes each to its own form', (
      tester,
    ) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DashboardContent(
              dashboard: _dashboard(),
              refuelingSupported: true,
              onRegisterAbastecimento: () => tapped.add('abastecer'),
              onRegisterMaintenance: () => tapped.add('manutencao'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abastecer'));
      await tester.tap(find.text('Registrar manutenção'));

      expect(tapped, ['abastecer', 'manutencao']);
      // The mileage has one prominent way in — the pencil beside the
      // reading — and the quick actions do not repeat it.
      expect(find.text('Atualizar km'), findsNothing);
    });

    // Absent, not disabled: an electric car has nothing to fill, and a greyed
    // control invites a tap that can never work.
    testWidgets('a vehicle that does not refuel gets no Abastecer', (
      tester,
    ) async {
      await _pump(tester, _dashboard());
      expect(find.text('Abastecer'), findsNothing);
      expect(find.text('Registrar manutenção'), findsOneWidget);
    });
  });

  // The verdict is the head of the attention strip and the only row about
  // what is late: tapping it opens the full list (or the one item, when
  // there is exactly one — see dashboard_content_test).
  group('attention strip', () {
    testWidgets('the verdict opens the full list', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DashboardContent(
              dashboard: _dashboard(overdue: 2),
              onSeeAllAlerts: () => opened = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('2 itens vencidos'));
      expect(opened, isTrue);
    });
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
    expect(
      routeForAlert(_alert(type: AlertReferenceType.seguro, id: 'sg-1')),
      isNot(AppRoutes.care),
    );
  });

  test('a plan alert opens the plan, a record alert opens the record', () {
    expect(
      routeForAlert(
        _alert(type: AlertReferenceType.maintenancePlan, id: 'pl-1'),
      ),
      AppRoutes.plan('pl-1'),
    );
    expect(
      routeForAlert(
        _alert(type: AlertReferenceType.maintenanceRecord, id: 'rc-1'),
      ),
      AppRoutes.maintenanceRecord('rc-1'),
    );
  });

  test('an unknown reference type is the only one that lands on Cuidados', () {
    expect(
      routeForAlert(_alert(type: AlertReferenceType.desconhecido, id: 'x')),
      AppRoutes.care,
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
  int? unknownHistory,
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
      unknownHistory: unknownHistory,
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
