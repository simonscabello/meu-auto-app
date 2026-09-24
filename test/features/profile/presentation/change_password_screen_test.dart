import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/profile/presentation/change_password_screen.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';

void main() {
  testWidgets('requires all three password fields before submitting', (
    tester,
  ) async {
    await _pump(tester);

    AppButton button() => tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Alterar senha'),
    );

    expect(button().onPressed, isNull);
    await tester.enterText(
      find.widgetWithText(TextField, 'Senha atual'),
      'senha-atual',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nova senha'),
      'senha-nova',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar nova senha'),
      'senha-nova',
    );
    await tester.pump();

    expect(button().onPressed, isNotNull);
  });

  testWidgets('rejects a confirmation that does not match locally', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Senha atual'),
      'senha-atual',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nova senha'),
      'senha-nova',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar nova senha'),
      'outra-senha',
    );
    await tester.pump();
    final submit = find.widgetWithText(AppButton, 'Alterar senha');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('As senhas não conferem.'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: const ChangePasswordScreen(),
      ),
    ),
  );
}
