import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/profile/presentation/personal_data_sheets.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';

/// The phone sheet is the one with a mask, so it is the one where "what is
/// typed" and "what is sent" can drift apart.
void main() {
  testWidgets('sends the digits, and waits for a whole number first', (
    tester,
  ) async {
    final adapter = _Adapter(status: 200);
    final result = await _open(tester, adapter);

    AppButton salvar() =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Salvar'));

    await tester.enterText(find.byType(TextField), '1191234');
    await tester.pump();
    expect(salvar().onPressed, isNull, reason: 'seven digits is not a phone');

    await tester.enterText(find.byType(TextField), '11912345678');
    await tester.pump();
    expect(salvar().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(AppButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(adapter.sent, {'phone': '11912345678'});
    expect(await result, isTrue);
  });

  testWidgets('a 422 on the phone lands under the field', (tester) async {
    final adapter = _Adapter(status: 422);
    await _open(tester, adapter);

    await tester.enterText(find.byType(TextField), '11912345678');
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o telefone com DDD.'), findsOneWidget);
    expect(find.text('Telefone'), findsOneWidget, reason: 'still open');
  });
}

Future<Future<bool>> _open(WidgetTester tester, _Adapter adapter) async {
  late Future<bool> result;
  final user = User(
    id: '11111111-1111-1111-1111-111111111111',
    name: 'Ana',
    email: 'ana@example.com',
    createdAt: DateTime.parse('2026-01-15T12:00:00Z').toLocal(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
        apiClientProvider.overrideWith((ref) {
          final api = ApiClient(adapter: adapter, logPrint: (_) {});
          ref.onDispose(api.close);
          return api;
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    result = PersonalDataSheets.phone(context, user),
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
  return Future.value(result);
}

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.status});

  final int status;
  Map<String, dynamic>? sent;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent = Map<String, dynamic>.from(options.data as Map);
    if (requestStream != null) await requestStream.drain<void>();
    final body = status == 200
        ? {
            'id': '11111111-1111-1111-1111-111111111111',
            'name': 'Ana',
            'email': 'ana@example.com',
            'created_at': '2026-01-15T12:00:00Z',
            'phone': '11912345678',
          }
        : {
            'error': {
              'code': 'validation_failed',
              'message': 'Não foi possível atualizar a conta.',
              'details': {
                'fields': {'phone': 'Informe o telefone com DDD.'},
              },
            },
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
