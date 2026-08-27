import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_form_screen.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';

void main() {
  late _Adapter adapter;

  setUp(() => adapter = _Adapter());

  testWidgets('cannot save without an item, and the reason is visible', (
    tester,
  ) async {
    await _open(tester, adapter);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Salvar'),
    );
    expect(button.onPressed, isNull);
    expect(find.text(MaintenanceRecordDraft.noItemsReason), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pump();
    expect(adapter.postedBodies, isEmpty);
  });

  testWidgets('a rollback opens the shared dialog and forcing resends', (
    tester,
  ) async {
    adapter.rejectFirstPost = true;
    await _open(tester, adapter, preselected: _oil);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Confira a quilometragem'), findsOneWidget);
    expect(find.textContaining('correction'), findsNothing);
    expect(find.textContaining('source'), findsNothing);

    await tester.tap(find.text('O valor está certo, registrar assim'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, hasLength(2));
    expect(adapter.postedBodies.first['id'], _fixedId);
    expect(adapter.postedBodies.last['id'], _fixedId);
    expect(adapter.postedBodies.last['mileage_km'], 48320);
    expect(adapter.postedBodies.last['items'], hasLength(1));
    expect(find.text('detalhe:$_fixedId'), findsOneWidget);
  });

  testWidgets('the amount the field shows is the amount that is sent', (
    tester,
  ) async {
    await _open(tester, adapter, preselected: _oil);

    // Typed the way a card machine takes it: digits fill from the cents up.
    // What matters is that the person is never asked to think in cents — the
    // field spells the amount out while they type, and the write agrees.
    await tester.dragUntilVisible(
      find.byType(AppMoneyField),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(AppMoneyField),
        matching: find.byType(TextField),
      ),
      '42000',
    );
    await tester.pump();
    expect(find.text('R\$ 420,00'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, hasLength(1));
    expect(adapter.postedBodies.single['total_cost_cents'], 42000);
  });

  testWidgets('the mileage is grouped as it is typed and sent as an int', (
    tester,
  ) async {
    await _open(tester, adapter, preselected: _oil);

    expect(find.text('48.320'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Quilometragem'),
      '104500',
    );
    await tester.pump();
    expect(find.text('104.500'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies.single['mileage_km'], 104500);
  });
}

Future<void> _open(
  WidgetTester tester,
  _Adapter adapter, {
  MaintenanceItem? preselected,
}) async {
  final client = ApiClient(adapter: adapter);
  addTearDown(client.close);

  final router = GoRouter(
    initialLocation: '/form',
    routes: [
      GoRoute(
        path: '/form',
        builder: (context, state) => MaintenanceFormScreen(
          vehicleId: _vehicleId,
          currentMileageKm: 48320,
          preselectedItem: preselected,
          newId: () => _fixedId,
        ),
      ),
      GoRoute(
        path: '/manutencoes/:recordId',
        builder: (context, state) =>
            Scaffold(body: Text('detalhe:${state.pathParameters['recordId']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
        apiClientProvider.overrideWithValue(client),
        maintenanceItemsProvider.overrideWith((ref) async => [_oil]),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

const _vehicleId = '22222222-2222-7222-8222-222222222222';
const _fixedId = '33333333-3333-7333-8333-333333333333';

const _oil = MaintenanceItem(
  id: 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa',
  slug: 'troca_oleo',
  name: 'Troca de óleo do motor',
  kind: MaintenanceItemKind.maintenance,
  vehicleType: 'car',
  isCustom: false,
  defaultStrategy: MaintenanceStrategy.periodic,
);

final class _Adapter implements HttpClientAdapter {
  bool rejectFirstPost = false;
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

      if (rejectFirstPost && postedBodies.length == 1) {
        return _json(422, {
          'error': {
            'code': 'odometer_rollback',
            'message':
                'A quilometragem informada é menor que a do registro anterior.',
            'details': {
              'previous_mileage_km': 98200,
              'previous_occurred_on': '2026-08-10',
              'submitted_mileage_km': body['mileage_km'],
              'hint':
                  'Se o painel foi trocado ou o valor anterior estava errado, '
                  'reenvie com source "correction".',
            },
          },
        });
      }
      return _json(201, _created());
    }

    if (options.method == 'GET' &&
        options.path.contains('/maintenance-items')) {
      return _json(200, {'data': []});
    }

    return _json(401, {
      'error': {'code': 'unauthorized', 'message': 'Sessão inválida.'},
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _created() {
  return {
    'id': _fixedId,
    'vehicle_id': _vehicleId,
    'occurred_on': '2026-08-26',
    'mileage_km': 48320,
    'kind': 'performed',
    'workshop_name': null,
    'total_cost_cents': 0,
    'notes': null,
    'items': [
      {
        'id': '44444444-4444-7444-8444-444444444444',
        'maintenance_item_id': _oil.id,
        'item_slug': _oil.slug,
        'item_name': _oil.name,
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
