import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
