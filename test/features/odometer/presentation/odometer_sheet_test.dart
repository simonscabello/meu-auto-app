import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/odometer/application/odometer_provider.dart';
import 'package:meu_auto/features/odometer/data/odometer_repository.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_sheet.dart';

/// `odometer_rollback` is the one business error the API gives its own code, and
/// the whole point is that it is a question, not a rejection. These tests hold
/// that line: it must never fall through to the generic error path, and the
/// override must only ever happen because a person chose it.
void main() {
  late _OdometerAdapter adapter;

  setUp(() => adapter = _OdometerAdapter());

  testWidgets('a rollback opens its own dialog, not the generic error', (
    tester,
  ) async {
    adapter.rejectFirstPost = true;
    await _open(tester, adapter);

    await tester.enterText(find.byType(TextField).first, '90000');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Confira a quilometragem'), findsOneWidget);
    expect(
      find.text(
        'Em 10/08/2026 o carro já estava com 98.200 km. '
        'Você informou 90.000 km, que é menos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Corrigir o valor'), findsOneWidget);
    expect(find.text('O valor está certo, registrar assim'), findsOneWidget);

    // The server's hint tells the CLIENT to resend with source "correction".
    // That is an instruction for the app, never words to put in front of a
    // person.
    expect(find.textContaining('correction'), findsNothing);
    expect(find.textContaining('source'), findsNothing);
  });

  testWidgets('choosing "o valor está certo" resends it as a correction', (
    tester,
  ) async {
    adapter.rejectFirstPost = true;
    await _open(tester, adapter);

    await tester.enterText(find.byType(TextField).first, '90000');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('O valor está certo, registrar assim'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, hasLength(2));
    expect(adapter.postedBodies.first['source'], 'manual');
    expect(adapter.postedBodies.last['source'], 'correction');
    expect(adapter.postedBodies.last['mileage_km'], 90000);
    // Same reading, retried — not a second one.
    expect(adapter.postedBodies.last['id'], adapter.postedBodies.first['id']);
  });

  testWidgets('choosing "corrigir o valor" sends nothing more', (tester) async {
    adapter.rejectFirstPost = true;
    await _open(tester, adapter);

    await tester.enterText(find.byType(TextField).first, '90000');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Corrigir o valor'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);
    // Still open, so the value can be fixed without retyping the rest.
    expect(find.text('Atualizar quilometragem'), findsOneWidget);
  });

  testWidgets('the field starts on the current mileage, fully selected', (
    tester,
  ) async {
    await _open(tester, adapter);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '48320');
    expect(field.controller!.selection.baseOffset, 0);
    expect(field.controller!.selection.extentOffset, 5);
    expect(find.text('Atual: 48.320 km'), findsOneWidget);
  });

  testWidgets('a plain success closes the sheet and confirms', (tester) async {
    await _open(tester, adapter);

    await tester.enterText(find.byType(TextField).first, '48900');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(adapter.postedBodies, hasLength(1));
    expect(adapter.postedBodies.single['source'], 'manual');
    expect(find.text('Atualizar quilometragem'), findsNothing);
    expect(
      find.text('Quilometragem atualizada para 48.900 km.'),
      findsOneWidget,
    );
  });
}

Future<void> _open(WidgetTester tester, _OdometerAdapter adapter) async {
  final client = ApiClient(adapter: adapter);
  addTearDown(client.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
        apiClientProvider.overrideWithValue(client),
        odometerRepositoryProvider.overrideWith(
          (ref) => OdometerRepository(api: client, newId: () => _fixedId),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => OdometerSheet.show(
                  context,
                  vehicleId: _vehicleId,
                  currentMileageKm: 48320,
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

const _vehicleId = '22222222-2222-7222-8222-222222222222';
const _fixedId = '33333333-3333-7333-8333-333333333333';

final class _OdometerAdapter implements HttpClientAdapter {
  bool rejectFirstPost = false;
  final List<Map<String, dynamic>> postedBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.contains('/odometer')) {
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
      return _json(201, _created(body['mileage_km'] as int));
    }

    // Anything else the widget tree happens to reach (the session bootstrap)
    // is answered as signed out, so the test never opens a real socket.
    return _json(401, {
      'error': {'code': 'unauthorized', 'message': 'Sessão inválida.'},
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _created(int mileageKm) {
  return {
    'reading': {
      'id': _fixedId,
      'vehicle_id': _vehicleId,
      'mileage_km': mileageKm,
      'occurred_on': '2026-08-26',
      'source': 'manual',
      'notes': null,
      'created_at': '2026-08-26T10:00:00Z',
    },
    'vehicle': {
      'id': _vehicleId,
      'vehicle_type': 'car',
      'brand': 'Fiat',
      'model': 'Argo',
      'current_mileage_km': mileageKm,
      'current_mileage_at': '2026-08-26',
      'created_at': '2026-01-01T10:00:00Z',
      'updated_at': '2026-08-26T10:00:00Z',
    },
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
