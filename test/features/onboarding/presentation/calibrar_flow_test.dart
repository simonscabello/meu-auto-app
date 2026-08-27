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

  testWidgets(
    'Não sei does not send a request and moves to the next question',
    (tester) async {
      await _open(tester, adapter, skipStore);

      expect(find.text('Quando foi a última troca de óleo?'), findsOneWidget);
      expect(find.text(calibrarQuestionSubtitle), findsOneWidget);
      expect(find.text('1 de 2'), findsOneWidget);
      expect(find.text('Hoje'), findsNothing);

      await tester.tap(find.text('Não sei'));
      await tester.pumpAndSettle();

      expect(adapter.postedBodies, isEmpty);
      expect(find.text('Quando foi a última revisão?'), findsOneWidget);
      expect(find.text('2 de 2'), findsOneWidget);

      await tester.tap(find.text('Não sei'));
      await tester.pumpAndSettle();

      expect(adapter.postedBodies, isEmpty);
      expect(find.text('Ver meu carro'), findsOneWidget);
    },
  );

  testWidgets('Pular tudo does not send a request', (tester) async {
    await _open(tester, adapter, skipStore);

    await tester.tap(find.text('Pular tudo'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, isEmpty);
    expect(await skipStore.wasSkipped(_vehicleId), isTrue);
    expect(find.text('início'), findsOneWidget);
  });

  testWidgets('Confirmar without a date does not send a request', (
    tester,
  ) async {
    await _open(tester, adapter, skipStore);

    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(adapter.postedBodies, isEmpty);
    expect(find.text('Informe a data.'), findsOneWidget);
    expect(find.text('Quando foi a última troca de óleo?'), findsOneWidget);
  });

  testWidgets(
    'Confirmar posts one declared record with no shop and no amount',
    (tester) async {
      await _open(tester, adapter, skipStore);

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
    await _open(tester, adapter, skipStore);

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
            _plan('troca_oleo', 'Troca de óleo do motor'),
            _plan('revisao', 'Revisão programada'),
            _plan('velas', 'Velas de ignição'),
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

MaintenancePlan _plan(String slug, String name) {
  return MaintenancePlan(
    id: 'plan-$slug',
    maintenanceItemId: 'item-$slug',
    itemSlug: slug,
    itemName: name,
    itemKind: MaintenanceItemKind.maintenance,
    alertKm: 500,
    alertDays: 15,
    origin: MaintenancePlanOrigin.suggested,
    status: MaintenanceStatus.semBaseline,
  );
}

const _vehicleId = '22222222-2222-7222-8222-222222222222';
const _fixedId = '33333333-3333-7333-8333-333333333333';

final class _Adapter implements HttpClientAdapter {
  bool rejectFirstPost = false;
  final List<Map<String, dynamic>> postedBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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
