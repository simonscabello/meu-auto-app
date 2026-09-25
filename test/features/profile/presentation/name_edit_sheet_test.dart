import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/profile/presentation/name_edit_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';

/// The name sheet is a form sheet: it closes through its own button, and that
/// button asks before a changed name is thrown away.
void main() {
  testWidgets('Salvar waits for a different name', (tester) async {
    await _open(tester);

    AppButton salvar() =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Salvar'));

    expect(find.text('Alterar nome'), findsOneWidget);
    expect(salvar().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Ana Maria');
    await tester.pump();
    expect(salvar().onPressed, isNotNull);
  });

  testWidgets('closing untouched just closes', (tester) async {
    await _open(tester);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    expect(find.text('Alterar nome'), findsNothing);
  });

  testWidgets('closing with a changed name asks first', (tester) async {
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'Ana Maria');
    await tester.pump();
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    expect(find.text('Descartar o que você preencheu?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Alterar nome'), findsOneWidget);
  });
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => NameEditSheet.show(context, 'Ana'),
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
