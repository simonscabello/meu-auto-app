import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/onboarding/application/calibrar_provider.dart';
import 'package:meu_auto/features/onboarding/data/calibrar_skip_store.dart';
import 'package:meu_auto/features/onboarding/domain/calibrar_questions.dart';
import 'package:meu_auto/features/onboarding/presentation/calibrar_flow.dart';

void main() {
  late _Adapter adapter;
  late MemoryCalibrarSkipStore skipStore;

  setUp(() {
    adapter = _Adapter();
    skipStore = MemoryCalibrarSkipStore();
  });

  // The first thing a new owner sees is a question about whether to answer
  // questions. Saying no costs one tap and loses nothing.
  testWidgets('opens on the invitation, not on a form', (tester) async {
    await _open(tester, adapter, skipStore);

    expect(find.text('Carro cadastrado'), findsOneWidget);
    expect(find.textContaining('2 perguntas rápidas'), findsOneWidget);
    expect(find.text('Quando foi a última troca de óleo?'), findsNothing);
    expect(find.text('Escolher data'), findsNothing);
  });

  testWidgets('Depois goes straight to the dashboard, writing nothing', (
    tester,
  ) async {
    await _open(tester, adapter, skipStore);

    await tester.tap(find.text('Depois'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, isEmpty);
    expect(adapter.patched, isEmpty);
    expect(await skipStore.wasSkipped(_vehicleId), isTrue);
    expect(find.text('início'), findsOneWidget);
  });

  testWidgets('the questions are the ones the server wrote', (tester) async {
    await _startAsking(tester, adapter, skipStore);

    expect(find.text('Quando foi a última troca de óleo?'), findsOneWidget);
    expect(find.text(calibrarQuestionSubtitle), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('Hoje'), findsNothing);
  });

  // "Não sei" is an answer now: it is written down so the question stops coming
  // back, and it still creates no service record.
  testWidgets('Não sei records the gap without inventing a record', (
    tester,
  ) async {
    await _startAsking(tester, adapter, skipStore);

    await tester.tap(find.text('Não sei'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, isEmpty);
    expect(adapter.patched, hasLength(1));
    expect(adapter.patched.single.path, '/maintenance-plans/plan-troca_oleo');
    expect(adapter.patched.single.body, {'history_status': 'unknown'});

    expect(find.text('Quando foi a última revisão?'), findsOneWidget);
    expect(find.text('2 de 2'), findsOneWidget);

    await tester.tap(find.text('Não sei'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, isEmpty);
    expect(adapter.patched, hasLength(2));
    expect(find.text('Ver meu carro'), findsOneWidget);
  });

  // A failed "não sei" must not trap anyone mid-onboarding. The worst case is
  // the question coming back later, which is where it started.
  testWidgets('Não sei still advances when the write fails', (tester) async {
    adapter.rejectPatches = true;
    await _startAsking(tester, adapter, skipStore);

    await tester.tap(find.text('Não sei'));
    await tester.pumpAndSettle();

    expect(find.text('Quando foi a última revisão?'), findsOneWidget);
  });

  testWidgets('Pular tudo does not send a request', (tester) async {
    await _startAsking(tester, adapter, skipStore);

    await tester.tap(find.text('Pular tudo'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, isEmpty);
    expect(await skipStore.wasSkipped(_vehicleId), isTrue);
    expect(find.text('início'), findsOneWidget);
  });

  testWidgets('Confirmar without a date does not send a request', (
    tester,
  ) async {
    await _startAsking(tester, adapter, skipStore);

    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(adapter.postedBodies, isEmpty);
    expect(find.text('Informe a data.'), findsOneWidget);
    expect(find.text('Quando foi a última troca de óleo?'), findsOneWidget);
  });

  testWidgets(
    'Confirmar posts one declared record with no shop and no amount',
    (tester) async {
      await _startAsking(tester, adapter, skipStore);

      await _pickDate(tester);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(adapter.postedBodies, hasLength(1));
      final body = adapter.postedBodies.single;
      expect(body['id'], _fixedId);
      expect(body['kind'], 'declared');
      expect(body['mileage_km'], 48320);
      expect(body.containsKey('workshop_name'), isFalse);
      expect(body.containsKey('total_cost_cents'), isFalse);
      expect(body['items'], [
        {'maintenance_item_id': 'item-troca_oleo'},
      ]);
      expect(find.text('Quando foi a última revisão?'), findsOneWidget);
      expect(find.text('2 de 2'), findsOneWidget);
    },
  );

  testWidgets('odometer rollback keeps the answer and lets the owner skip it', (
    tester,
  ) async {
    adapter.rejectFirstPost = true;
    await _startAsking(tester, adapter, skipStore);

    await _pickDate(tester);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Confira a quilometragem'), findsOneWidget);
    expect(find.textContaining('correction'), findsNothing);
    expect(find.textContaining('source'), findsNothing);

    await tester.tap(find.text('Corrigir o valor'));
    await tester.pumpAndSettle();

    expect(find.text('Quando foi a última troca de óleo?'), findsOneWidget);
    expect(adapter.postedBodies, hasLength(1));

    await tester.tap(find.text('Não sei'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, hasLength(1));
    expect(find.text('Quando foi a última revisão?'), findsOneWidget);
  });
}

Future<void> _pickDate(WidgetTester tester) async {
  await tester.tap(find.text('Escolher data'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _startAsking(
  WidgetTester tester,
  _Adapter adapter,
  MemoryCalibrarSkipStore skipStore,
) async {
  await _open(tester, adapter, skipStore);
  await tester.tap(find.text('Contar agora'));
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester,
  _Adapter adapter,
  MemoryCalibrarSkipStore skipStore,
) async {
  final client = ApiClient(adapter: adapter);
  addTearDown(client.close);

  final router = GoRouter(
    initialLocation: '/calibrar',
    routes: [
      GoRoute(
        path: '/calibrar',
        builder: (context, state) => CalibrarFlow(
          vehicleId: _vehicleId,
          currentMileageKm: 48320,
          newId: () => _fixedId,
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('início')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
        apiClientProvider.overrideWithValue(client),
        calibrarSkipStoreProvider.overrideWithValue(skipStore),
        maintenancePlansProvider(_vehicleId).overrideWith(
          (ref) async => [
            _plan(
              'troca_oleo',
              'Troca de óleo do motor',
              question: 'Quando foi a última troca de óleo?',
              priority: 100,
            ),
            _plan(
              'revisao',
              'Revisão programada',
              question: 'Quando foi a última revisão?',
              priority: 95,
            ),
            // No question in the catalogue, so nothing to ask. This is what
            // keeps the app from inventing wording for an item.
            _plan('rodizio_pneus', 'Rodízio de pneus', priority: 30),
          ],
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MaintenancePlan _plan(
  String slug,
  String name, {
  required int priority,
  String? question,
}) {
  return MaintenancePlan(
    id: 'plan-$slug',
    maintenanceItemId: 'item-$slug',
    itemSlug: slug,
    itemName: name,
    itemKind: MaintenanceItemKind.maintenance,
    alertKm: 500,
    alertDays: 15,
    origin: MaintenancePlanOrigin.suggested,
    strategy: MaintenanceStrategy.periodic,
    historyStatus: MaintenanceHistoryStatus.notAsked,
    historyQuestion: question,
    historyPriority: priority,
    status: MaintenanceStatus.semBaseline,
  );
}

const _vehicleId = '22222222-2222-7222-8222-222222222222';
const _fixedId = '33333333-3333-7333-8333-333333333333';

final class _Patch {
  const _Patch(this.path, this.body);
  final String path;
  final Map<String, dynamic> body;
}

final class _Adapter implements HttpClientAdapter {
  bool rejectFirstPost = false;
  bool rejectPatches = false;
  final List<Map<String, dynamic>> postedBodies = [];
  final List<_Patch> patched = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PATCH') {
      patched.add(
        _Patch(options.path, Map<String, dynamic>.from(options.data as Map)),
      );
      if (rejectPatches) {
        return _json(500, {
          'error': {'code': 'internal', 'message': 'falhou'},
        });
      }
      return _json(200, _plannedPatch());
    }
    if (options.method == 'POST') {
      postedBodies.add(Map<String, dynamic>.from(options.data as Map));
      if (rejectFirstPost && postedBodies.length == 1) {
        return _json(422, {
          'error': {
            'code': 'odometer_rollback',
            'message':
                'A quilometragem informada é menor que a do registro anterior.',
            'details': {
              'previous_mileage_km': 98200,
              'previous_occurred_on': '2026-08-10',
              'submitted_mileage_km': options.data['mileage_km'],
              'hint':
                  'Se o painel foi trocado ou o valor anterior estava errado, '
                  'reenvie com source "correction".',
            },
          },
        });
      }
      return _json(201, _created());
    }
    return _json(500, {
      'error': {'code': 'internal', 'message': 'não deveria chegar aqui'},
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _plannedPatch() {
  return {
    'id': 'plan-troca_oleo',
    'maintenance_item_id': 'item-troca_oleo',
    'interval_km': 10000,
    'interval_months': 12,
    'interval_days': null,
    'alert_km': 1000,
    'alert_days': 30,
    'origin': 'user',
    'strategy': 'periodic',
    'history_status': 'unknown',
    'notes': null,
  };
}

Map<String, dynamic> _created() {
  return {
    'id': _fixedId,
    'vehicle_id': _vehicleId,
    'occurred_on': '2026-03-10',
    'mileage_km': 48320,
    'kind': 'declared',
    'workshop_name': null,
    'total_cost_cents': 0,
    'notes': null,
    'items': [
      {
        'id': '44444444-4444-7444-8444-444444444444',
        'maintenance_item_id': 'item-troca_oleo',
        'item_slug': 'troca_oleo',
        'item_name': 'Troca de óleo do motor',
      },
    ],
    'created_at': '2026-08-26T10:00:00Z',
    'updated_at': '2026-08-26T10:00:00Z',
  };
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
