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

      expect(find.text(PasswordResetCopy.requestAccepted), findsOneWidget);
      expect(find.textContaining('enviamos para você'), findsNothing);
      expect(find.textContaining('enviamos para o seu'), findsNothing);
      expect(find.textContaining('conta cadastrada'), findsNothing);
    },
  );
}
