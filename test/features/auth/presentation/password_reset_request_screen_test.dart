import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/auth/domain/password_reset_copy.dart';
import 'package:meu_auto/features/auth/presentation/password_reset_request_screen.dart';

void main() {
  testWidgets(
    'the success copy is neutral and never confirms that a message was sent to this address',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PasswordResetRequestSuccess(onBackToLogin: () {}),
        ),
      );

      expect(
        find.textContaining(PasswordResetCopy.requestAccepted),
        findsOneWidget,
      );
      expect(find.textContaining('enviamos para você'), findsNothing);
      expect(find.textContaining('enviamos para o seu'), findsNothing);
      expect(find.textContaining('conta cadastrada'), findsNothing);
    },
  );

  testWidgets('the success page has one way on, back to the sign-in', (
    tester,
  ) async {
    var back = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PasswordResetRequestSuccess(onBackToLogin: () => back++),
      ),
    );

    await tester.tap(find.text('Voltar ao login'));
    await tester.pump();

    expect(back, 1);
  });
}
