import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/presentation/cuidados_screen.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';

void main() {
  late _Adapter adapter;
  late _Counts counts;

  setUp(() {
    adapter = _Adapter();
    counts = _Counts();
  });

  testWidgets('Feito posts one line, today, and no mileage_km key', (
    tester,
  ) async {
    await _open(tester, adapter, counts);

    await tester.tap(find.text('Feito'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, hasLength(1));
    final body = adapter.postedBodies.single;
    expect(body['id'], _fixedId);
    expect(body['occurred_on'], CivilDate.todayLocal().toJson());
    expect(body.containsKey('mileage_km'), isFalse);
    expect(body['items'], [
      {'maintenance_item_id': _care.maintenanceItemId},
    ]);
    expect(find.text('Registrado hoje · Próxima verificação em 15 dias'), findsOneWidget);
  });

  testWidgets('a 200 retry is success, same as 201', (tester) async {
    adapter.postStatus = 200;
    await _open(tester, adapter, counts);

    await tester.tap(find.text('Feito'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Registrado hoje'), findsOneWidget);
    expect(find.textContaining('Sessão inválida'), findsNothing);
  });

  testWidgets('the button stays blocked until the write finishes', (
    tester,
  ) async {
    adapter.holdPost = Completer<void>();
    await _open(tester, adapter, counts);

    await tester.tap(find.text('Feito'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.postedBodies, hasLength(1));
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Feito'),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Feito'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(adapter.postedBodies, hasLength(1));

    adapter.holdPost!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a failure stays on the card and shows the server message', (
    tester,
  ) async {
    adapter.failPost = true;
    await _open(tester, adapter, counts);

    await tester.tap(find.text('Feito'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível registrar.'), findsOneWidget);
    expect(find.text('Feito'), findsOneWidget);
    expect(find.textContaining('Registrado hoje'), findsNothing);
  });

  testWidgets('a successful write invalidates plans, dashboard and timeline', (
    tester,
  ) async {
    await _open(tester, adapter, counts);

    expect(counts.plans, 1);
    expect(counts.dashboard, 1);
    expect(adapter.timelineGets, 1);

    await tester.tap(find.text('Feito'));
    await tester.pumpAndSettle();

    expect(counts.plans, 2);
    expect(counts.dashboard, 2);
    expect(adapter.timelineGets, 2);
  });
}

Future<void> _open(WidgetTester tester, _Adapter adapter, _Counts counts) async {
  final client = ApiClient(adapter: adapter, logPrint: (_) {});
  addTearDown(client.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
        apiClientProvider.overrideWithValue(client),
        maintenancePlansProvider(_vehicleId).overrideWith((ref) async {
          counts.plans++;
          if (counts.plans == 1) return [_care];
          return [_careRecorded];
        }),
        dashboardProvider(_vehicleId).overrideWith((ref) async {
          counts.dashboard++;
          return _dashboard();
        }),
        obligationsProvider(_vehicleId).overrideWith((ref) async => []),
        segurosProvider(_vehicleId).overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              _ProviderProbe(vehicleId: _vehicleId, counts: counts),
              Expanded(
                child: CuidadosView(vehicleId: _vehicleId, newId: () => _fixedId),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ProviderProbe extends ConsumerWidget {
  const _ProviderProbe({required this.vehicleId, required this.counts});

  final String vehicleId;
  final _Counts counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dashboardProvider(vehicleId));
    ref.watch(timelineProvider(vehicleId));
    return const SizedBox.shrink();
  }
}

class _Counts {
  int plans = 0;
  int dashboard = 0;
}

const _vehicleId = '22222222-2222-7222-8222-222222222222';
const _fixedId = '33333333-3333-7333-8333-333333333333';

const _care = MaintenancePlan(
  id: 'plan-calibrar_pneus',
  maintenanceItemId: 'item-calibrar_pneus',
  itemSlug: 'calibrar_pneus',
  itemName: 'Calibrar os pneus',
  itemKind: MaintenanceItemKind.care,
  intervalDays: 15,
  alertKm: 500,
  alertDays: 5,
  origin: MaintenancePlanOrigin.suggested,
  strategy: MaintenanceStrategy.periodic,
  historyStatus: MaintenanceHistoryStatus.notAsked,
  status: MaintenanceStatus.vencido,
);

final _careRecorded = MaintenancePlan(
  id: _care.id,
  maintenanceItemId: _care.maintenanceItemId,
  itemSlug: _care.itemSlug,
  itemName: _care.itemName,
  itemKind: MaintenanceItemKind.care,
  intervalDays: 15,
  alertKm: 500,
  alertDays: 5,
  origin: MaintenancePlanOrigin.suggested,
  strategy: MaintenanceStrategy.periodic,
  historyStatus: MaintenanceHistoryStatus.notAsked,
  status: MaintenanceStatus.emDia,
  remainingDays: 15,
  lastOccurredOn: CivilDate.todayLocal(),
  dueOn: const CivilDate(2026, 9, 11),
);

Dashboard _dashboard() {
  return const Dashboard(
    vehicle: DashboardVehicle(
      id: _vehicleId,
      brand: 'Fiat',
      model: 'Argo',
      nickname: 'Argolino',
      plate: 'ABC1D23',
    ),
    odometer: DashboardOdometer(
      currentKm: 48320,
      recordedOn: CivilDate(2026, 8, 10),
    ),
    alerts: DashboardAlerts(
      overdue: 1,
      dueSoon: 0,
      needsBaseline: 0,
      items: [],
    ),
    profile: DashboardProfile.empty,
    costs: DashboardCosts(
      periodMonths: 12,
      since: CivilDate(2025, 8, 26),
      maintenanceCents: Money.fromCents(0),
      obligationsCents: Money.fromCents(0),
      seguroCents: Money.fromCents(0),
      trackedCents: Money.fromCents(0),
      trackedCategories: [],
    ),
  );
}

final class _Adapter implements HttpClientAdapter {
  Completer<void>? holdPost;
  bool failPost = false;
  int postStatus = 201;
  int timelineGets = 0;
  final List<Map<String, dynamic>> postedBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' &&
        options.path.contains('/maintenance-records')) {
      final body = Map<String, dynamic>.from(options.data as Map);
      postedBodies.add(body);
      final hold = holdPost;
      if (hold != null) await hold.future;
      if (failPost) {
        return _json(422, {
          'error': {
            'code': 'validation_failed',
            'message': 'Não foi possível registrar.',
          },
        });
      }
      return _json(postStatus, {
        'id': body['id'],
        'vehicle_id': _vehicleId,
        'occurred_on': body['occurred_on'],
        'mileage_km': null,
        'kind': 'performed',
        'workshop_name': null,
        'total_cost_cents': 0,
        'notes': null,
        'items': [
          {
            'id': '44444444-4444-7444-8444-444444444444',
            'maintenance_item_id': _care.maintenanceItemId,
            'item_slug': _care.itemSlug,
            'item_name': _care.itemName,
          },
        ],
        'created_at': '2026-08-27T10:00:00Z',
        'updated_at': '2026-08-27T10:00:00Z',
      });
    }

    if (options.method == 'GET' && options.path.contains('/timeline')) {
      timelineGets++;
      return _json(200, {'data': <Object?>[], 'next_cursor': null});
    }

    return _json(401, {
      'error': {'code': 'unauthorized', 'message': 'Sessão inválida.'},
    });
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
