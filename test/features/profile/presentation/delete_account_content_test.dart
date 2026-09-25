import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/profile/domain/delete_account_copy.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/profile/presentation/delete_account_screen.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';

void main() {
  testWidgets(
    'the destructive button stays disabled until a password is typed',
    (tester) async {
      final password = TextEditingController();
      addTearDown(password.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DeleteAccountContent(
              passwordController: password,
              passwordError: null,
              banner: null,
              submitting: false,
              hasPassword: false,
              onPasswordChanged: () {},
              onSubmit: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Excluir minha conta'),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'says in one sentence what is lost, and the button says the verb in red',
    (tester) async {
      final password = TextEditingController(text: 'senha-atual');
      addTearDown(password.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DeleteAccountContent(
              passwordController: password,
              passwordError: null,
              banner: null,
              submitting: false,
              hasPassword: true,
              onPasswordChanged: () {},
              onSubmit: () {},
            ),
          ),
        ),
      );

      expect(find.text(DeleteAccountCopy.consequence), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Senha'), findsOneWidget);

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Excluir minha conta'),
      );
      expect(button.variant, AppButtonVariant.destructive);
      expect(button.onPressed, isNotNull);
      expect(find.widgetWithText(AppButton, 'Confirmar'), findsNothing);
    },
  );
}
