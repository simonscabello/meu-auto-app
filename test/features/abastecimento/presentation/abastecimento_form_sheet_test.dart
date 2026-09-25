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
import 'package:meu_auto/features/abastecimento/application/abastecimento_provider.dart';
import 'package:meu_auto/features/abastecimento/data/abastecimento_repository.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_form_sheet.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_segmented.dart';

void main() {
  late _FillAdapter adapter;

  setUp(() => adapter = _FillAdapter());

  testWidgets('the field starts on the current mileage, fully selected', (
    tester,
  ) async {
    await _open(tester, adapter);

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AppKmField),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '96.420');
    expect(field.controller!.selection.baseOffset, 0);
    expect(field.controller!.selection.extentOffset, '96.420'.length);
  });

  testWidgets('tanque cheio starts checked and the date reads Hoje', (
    tester,
  ) async {
    await _open(tester, adapter);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Hoje'), findsOneWidget);
  });

  testWidgets('a new fill is titled Abastecer and saved with Salvar', (
    tester,
  ) async {
    await _open(tester, adapter);

    expect(find.text('Abastecer'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Salvar'), findsOneWidget);
    // One primary action: the way to the history is not on the form.
    expect(find.text('Ver histórico'), findsNothing);
  });

  testWidgets('editing says so and opens the details it already has', (
    tester,
  ) async {
    await _open(tester, adapter, existing: _existing());

    expect(find.text('Editar abastecimento'), findsOneWidget);
    expect(find.text('Posto'), findsOneWidget);
    expect(find.text('Auto Posto Primavera'), findsOneWidget);
    expect(find.text('Adicionar detalhes'), findsNothing);
  });

  testWidgets('posto and observação stay behind Adicionar detalhes', (
    tester,
  ) async {
    await _open(tester, adapter);

    expect(find.text('Posto'), findsNothing);
    expect(find.text('Observação'), findsNothing);
    expect(find.text('Adicionar detalhes'), findsOneWidget);

    await tester.ensureVisible(find.text('Adicionar detalhes'));
    await tester.tap(find.text('Adicionar detalhes'));
    await tester.pumpAndSettle();

    expect(find.text('Posto'), findsOneWidget);
    expect(find.text('Observação'), findsOneWidget);
  });

  testWidgets('a single fuel is stated, not chosen', (tester) async {
    await _open(tester, adapter, fuelTypes: const [AbastecimentoFuel.diesel]);

    expect(find.byType(AppSegmented<AbastecimentoFuel>), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Diesel'), findsOneWidget);
  });

  testWidgets('several fuels are one tap apart and start on the last used', (
    tester,
  ) async {
    await _open(
      tester,
      adapter,
      fuelTypes: const [AbastecimentoFuel.gasolina, AbastecimentoFuel.etanol],
      lastFuel: AbastecimentoFuel.etanol,
    );

    final picker = find.byType(AppSegmented<AbastecimentoFuel>);
    expect(picker, findsOneWidget);
    expect(
      tester.widget<AppSegmented<AbastecimentoFuel>>(picker).value,
      AbastecimentoFuel.etanol,
    );

    await tester.tap(find.text('Gasolina'));
    await tester.pumpAndSettle();
    await _fillRequired(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies.single['fuel'], 'gasolina');
  });

  testWidgets('saving posts volume_ml from a comma decimal', (tester) async {
    await _open(tester, adapter);
    await _fillRequired(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, hasLength(1));
    expect(adapter.postedBodies.single['volume_ml'], 34700);
    expect(adapter.postedBodies.single['mileage_km'], 96420);
    expect(adapter.postedBodies.single['total_cost_cents'], 23840);
    expect(adapter.postedBodies.single['fuel'], 'diesel');
    expect(adapter.postedBodies.single['full_tank'], isTrue);
    expect(adapter.postedBodies.single['source'], 'manual');
    expect(find.text('Abastecimento registrado.'), findsOneWidget);
  });

  testWidgets('a rollback opens its own dialog, not the generic error', (
    tester,
  ) async {
    adapter.rejectFirstPost = true;
    await _open(tester, adapter);
    await _fillRequired(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Confira a quilometragem'), findsOneWidget);
    expect(find.text('O valor está certo, registrar assim'), findsOneWidget);
    expect(find.textContaining('correction'), findsNothing);
    expect(find.textContaining('source'), findsNothing);
  });

  testWidgets('choosing "o valor está certo" resends it as a correction', (
    tester,
  ) async {
    adapter.rejectFirstPost = true;
    await _open(tester, adapter);
    await _fillRequired(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('O valor está certo, registrar assim'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, hasLength(2));
    expect(adapter.postedBodies.first['source'], 'manual');
    expect(adapter.postedBodies.last['source'], 'correction');
    expect(adapter.postedBodies.last['id'], adapter.postedBodies.first['id']);
    expect(adapter.postedBodies.last['volume_ml'], 34700);
  });

  testWidgets('choosing "corrigir o valor" keeps the form and sends nothing', (
    tester,
  ) async {
    adapter.rejectFirstPost = true;
    await _open(tester, adapter);
    await _fillRequired(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Corrigir o valor'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Abastecer'), findsOneWidget);
  });

  testWidgets('lays out on 360x640 with the font turned up', (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.6),
                size: Size(360, 640),
              ),
              child: Scaffold(
                body: AbastecimentoFormSheet(
                  vehicleId: _vehicleId,
                  currentMileageKm: 139011,
                  fuelTypes: const [
                    AbastecimentoFuel.gasolina,
                    AbastecimentoFuel.etanol,
                    AbastecimentoFuel.diesel,
                    AbastecimentoFuel.gnv,
                  ],
                  existing: _existing(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(find.byType(AppLitersField), '34,7');
  await tester.enterText(find.byType(AppMoneyField), '23840');
}

Future<void> _open(
  WidgetTester tester,
  _FillAdapter adapter, {
  List<AbastecimentoFuel> fuelTypes = const [AbastecimentoFuel.diesel],
  AbastecimentoFuel? lastFuel,
  Abastecimento? existing,
}) async {
  final client = ApiClient(adapter: adapter, logPrint: (_) {});
  addTearDown(client.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
        apiClientProvider.overrideWithValue(client),
        abastecimentoRepositoryProvider.overrideWith(
          (ref) => AbastecimentoRepository(api: client, newId: () => _fixedId),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => AbastecimentoFormSheet.show(
                  context,
                  vehicleId: _vehicleId,
                  currentMileageKm: 96420,
                  fuelTypes: fuelTypes,
                  lastFuel: lastFuel,
                  existing: existing,
                  newId: () => _fixedId,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Abastecimento _existing() {
  return Abastecimento(
    id: _fixedId,
    vehicleId: _vehicleId,
    occurredOn: const CivilDate(2026, 9, 21),
    mileageKm: 96420,
    volumeMl: 39830,
    totalCostCents: const Money.fromCents(24655),
    pricePerLiterCents: const Money.fromCents(619),
    fuel: AbastecimentoFuel.diesel,
    fullTank: true,
    stationName: 'Auto Posto Primavera',
    consumption: const Consumption(
      value: 17.2,
      unit: 'km_per_liter',
      status: ConsumptionStatus.ok,
    ),
    createdAt: DateTime.utc(2026, 9, 21),
    updatedAt: DateTime.utc(2026, 9, 21),
  );
}

const _vehicleId = '22222222-2222-7222-8222-222222222222';
const _fixedId = '33333333-3333-7333-8333-333333333333';

final class _FillAdapter implements HttpClientAdapter {
  bool rejectFirstPost = false;
  final List<Map<String, dynamic>> postedBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.contains('/abastecimentos')) {
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
      return _json(201, _created(body));
    }

    return _json(401, {
      'error': {'code': 'unauthorized', 'message': 'Sessão inválida.'},
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _created(Map<String, dynamic> body) {
  return {
    'id': body['id'] ?? _fixedId,
    'vehicle_id': _vehicleId,
    'occurred_on': body['occurred_on'] ?? '2026-08-27',
    'mileage_km': body['mileage_km'],
    'volume_ml': body['volume_ml'],
    'total_cost_cents': body['total_cost_cents'],
    'price_per_liter_cents': 687,
    'fuel': body['fuel'],
    'full_tank': body['full_tank'] ?? true,
    'station_name': body['station_name'],
    'notes': body['notes'],
    'consumption': {
      'value': null,
      'unit': 'km_per_liter',
      'status': 'insufficient_data',
    },
    'created_at': '2026-08-27T10:00:00Z',
    'updated_at': '2026-08-27T10:00:00Z',
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
