import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';

/// Android draws the app edge to edge from target SDK 35, and the
/// three-button navigation bar sat over whatever a sheet ended with — on
/// "Editar abastecimento", the "Salvar" button. Every sheet opens through
/// `showAppSheet`, so the inset is proved once here for both interiors.
void main() {
  const screen = Size(360, 780);
  const navBar = 48.0;

  for (final frame in [false, true]) {
    final kind = frame ? 'AppSheetFrame' : 'AppSheetBody';

    testWidgets('$kind ends above the navigation bar', (tester) async {
      await _open(tester, screen: screen, bottomBar: navBar, frame: frame);

      final button = tester.getRect(find.widgetWithText(AppButton, 'Salvar'));
      expect(button.bottom, lessThanOrEqualTo(screen.height - navBar));
    });

    // A frame is a fixed height and its lists handle the keyboard
    // themselves; only the fitting body lifts above it.
    if (frame) continue;
    testWidgets('$kind does not pad twice with the keyboard up', (
      tester,
    ) async {
      const keyboard = 300.0;
      await _open(
        tester,
        screen: screen,
        bottomBar: navBar,
        keyboard: keyboard,
        frame: frame,
      );

      final button = tester.getRect(find.widgetWithText(AppButton, 'Salvar'));
      expect(button.bottom, lessThanOrEqualTo(screen.height - keyboard));
      // It sits on the keyboard with its usual 24dp and nothing more: the
      // keyboard's inset already covers the bar.
      expect(button.bottom, greaterThan(screen.height - keyboard - 40));
    });
  }
}

Future<void> _open(
  WidgetTester tester, {
  required Size screen,
  required double bottomBar,
  double keyboard = 0,
  required bool frame,
}) async {
  tester.view.physicalSize = screen * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.viewPadding = FakeViewPadding(bottom: bottomBar * 3);
  tester.view.padding = FakeViewPadding(
    bottom: keyboard > 0 ? 0 : bottomBar * 3,
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  addTearDown(tester.view.reset);

  const button = AppButton(label: 'Salvar', onPressed: null, expanded: true);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAppSheet<void>(
                context,
                isForm: true,
                builder: (_) => frame
                    ? const AppSheetFrame(
                        child: Column(
                          children: [
                            Expanded(child: SizedBox.shrink()),
                            button,
                          ],
                        ),
                      )
                    : const AppSheetBody(
                        children: [SizedBox(height: 120), button],
                      ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}
