import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/presentation/care_periodicity_sheet.dart';

void main() {
  late _Adapter adapter;

  setUp(() => adapter = _Adapter());

  testWidgets('offers the six presets and hides alert fields', (tester) async {
    await _open(tester, adapter);

    expect(find.text('Padrão recomendado (a cada 21 dias)'), findsOneWidget);
    expect(find.text('Toda semana'), findsOneWidget);
    expect(find.text('A cada 15 dias'), findsOneWidget);
    expect(find.text('Todo mês'), findsOneWidget);
    expect(find.text('Personalizado…'), findsOneWidget);
    expect(find.text('Não lembrar'), findsOneWidget);
    expect(find.text('Avisar com antecedência de'), findsNothing);
    expect(find.text('A cada quantos km'), findsNothing);
    expect(find.text('Quilômetros'), findsNothing);
  });

  testWidgets('recommended sends the catalogue days and no alerts', (
    tester,
  ) async {
    await _open(tester, adapter);

    await tester.tap(find.text('Padrão recomendado (a cada 21 dias)'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(adapter.patched, {'interval_days': 21});
  });

  testWidgets('weekly, fortnight and month map to days', (tester) async {
    await _open(tester, adapter);
    await tester.tap(find.text('Toda semana'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(adapter.patched, {'interval_days': 7});

    adapter.patched = null;
    await _open(tester, adapter);
    await tester.tap(find.text('A cada 15 dias'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(adapter.patched, {'interval_days': 15});

    adapter.patched = null;
    await _open(tester, adapter);
    await tester.tap(find.text('Todo mês'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(adapter.patched, {'interval_days': 30});
  });

  testWidgets('custom sends the typed number', (tester) async {
    await _open(tester, adapter);

    await tester.tap(find.text('Personalizado…'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '10');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(adapter.patched, {'interval_days': 10});
  });

  testWidgets('not reminding clears the three intervals', (tester) async {
    await _open(tester, adapter);

    await tester.tap(find.text('Não lembrar'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(adapter.patched!['clear_intervals'], isTrue);
    expect(adapter.patched!['interval_km'], isNull);
    expect(adapter.patched!['interval_months'], isNull);
    expect(adapter.patched!['interval_days'], isNull);
  });
}

Future<void> _open(WidgetTester tester, _Adapter adapter) async {
  final client = ApiClient(adapter: adapter, logPrint: (_) {});
  addTearDown(client.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
        apiClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const CarePeriodicitySheet(
                  vehicleId: _vehicleId,
                  plan: _care,
                  defaultIntervalDays: 21,
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

const _vehicleId = '22222222-2222-7222-8222-222222222222';

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
  status: MaintenanceStatus.emDia,
);

final class _Adapter implements HttpClientAdapter {
  Map<String, dynamic>? patched;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PATCH' &&
        options.path.contains('/maintenance-plans/')) {
      patched = Map<String, dynamic>.from(options.data as Map);
      return _json(200, {
        'id': _care.id,
        'maintenance_item_id': _care.maintenanceItemId,
        'interval_km': null,
        'interval_months': null,
        'interval_days': patched!['interval_days'],
        'alert_km': 1,
        'alert_days': 1,
        'origin': 'user',
        'strategy': 'periodic',
        'history_status': 'not_asked',
        'notes': null,
      });
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
