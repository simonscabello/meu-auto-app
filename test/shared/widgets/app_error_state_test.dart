import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';

void main() {
  testWidgets('offline names the product as online-only and offers a retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppErrorState.fromError(
            error: const ApiFailure.semConexao(),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text(AppErrorState.offlineTitle), findsOneWidget);
    expect(
      find.text(
        'O Meu Auto precisa de internet para funcionar. Conecte-se e tente de novo.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    expect(retried, isTrue);
  });

  testWidgets('an internal failure shows the request id in small type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppErrorState.fromError(
            error: const ApiFailure(
              code: ApiErrorCode.internal,
              message: 'Algo deu errado no servidor.',
              requestId: 'req-abc-123',
            ),
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('Algo deu errado no servidor.'), findsOneWidget);
    expect(find.text('Referência: req-abc-123'), findsOneWidget);
    expect(find.text(AppErrorState.offlineTitle), findsNothing);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
