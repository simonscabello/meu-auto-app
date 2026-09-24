import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

void main() {
  // A snack bar with an action persists by default. The undo after Feito used
  // to sit over every tab until it was tapped.
  testWidgets('an undo confirmation goes away on its own', (tester) async {
    await _pumpAndShow(tester, accessibleNavigation: false);

    expect(find.text('Desfazer'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Desfazer'), findsNothing);
  });

  testWidgets('under a screen reader the undo waits to be reached', (
    tester,
  ) async {
    await _pumpAndShow(tester, accessibleNavigation: true);

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Desfazer'), findsOneWidget);
  });
}

Future<void> _pumpAndShow(
  WidgetTester tester, {
  required bool accessibleNavigation,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(accessibleNavigation: accessibleNavigation),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSnackBar(
                ScaffoldMessenger.of(context),
                message: 'Calibrar os pneus: registrado hoje.',
                onUndo: () {},
              ),
              child: const Text('mostrar'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('mostrar'));
  await tester.pumpAndSettle();
}
