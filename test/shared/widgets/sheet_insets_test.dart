import 'dart:math' as math;

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

  // The engine reports the bottom padding as the navigation bar minus the
  // keyboard, so it reaches zero partway up the keyboard's slide. The sheet
  // used to change shape at zero: the whole form was built again from
  // scratch, the field lost its focus and the keyboard went straight back
  // down. No sheet with a field could be typed into on a phone with a
  // navigation bar — "Editar manutenção" was the one reported. The tests
  // above open the sheet with the keyboard already up, so they never saw
  // the moment it crosses.
  testWidgets('a field keeps its focus and its text while the keyboard '
      'rises and falls', (tester) async {
    var builds = 0;
    await _openForm(
      tester,
      screen: screen,
      bottomBar: navBar,
      onInit: () => builds++,
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    tester.testTextInput.enterText('420');
    await tester.pump();

    // Up one frame at a time, as Android reports the keyboard's slide.
    for (final keyboard in [16.0, 40.0, 48.0, 90.0, 200.0, 300.0]) {
      await _setKeyboard(tester, bottomBar: navBar, keyboard: keyboard);
    }
    expect(builds, 1, reason: 'the form was built again from scratch');
    expect(_fieldHasFocus(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text('420'), findsOneWidget);

    // Typing with the keyboard up still reaches the field.
    tester.testTextInput.enterText('42000');
    await tester.pump();
    expect(find.text('42000'), findsOneWidget);

    // And back down — the back button hides the keyboard before it closes
    // anything — without losing what was typed.
    for (final keyboard in [200.0, 48.0, 20.0, 0.0]) {
      await _setKeyboard(tester, bottomBar: navBar, keyboard: keyboard);
    }
    expect(builds, 1, reason: 'the form was built again from scratch');
    expect(find.text('42000'), findsOneWidget);
  });
}

Future<void> _open(
  WidgetTester tester, {
  required Size screen,
  required double bottomBar,
  double keyboard = 0,
  required bool frame,
}) async {
  const button = AppButton(label: 'Salvar', onPressed: null, expanded: true);
  await _pumpOpener(
    tester,
    screen: screen,
    bottomBar: bottomBar,
    keyboard: keyboard,
    builder: (_) => frame
        ? const AppSheetFrame(
            child: Column(
              children: [
                Expanded(child: SizedBox.shrink()),
                button,
              ],
            ),
          )
        : const AppSheetBody(children: [SizedBox(height: 120), button]),
  );
}

Future<void> _openForm(
  WidgetTester tester, {
  required Size screen,
  required double bottomBar,
  required VoidCallback onInit,
}) {
  return _pumpOpener(
    tester,
    screen: screen,
    bottomBar: bottomBar,
    builder: (_) => _Form(onInit: onInit),
  );
}

Future<void> _pumpOpener(
  WidgetTester tester, {
  required Size screen,
  required double bottomBar,
  double keyboard = 0,
  required WidgetBuilder builder,
}) async {
  tester.view.physicalSize = screen * 3;
  tester.view.devicePixelRatio = 3;
  _applyInsets(tester, bottomBar: bottomBar, keyboard: keyboard);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showAppSheet<void>(context, isForm: true, builder: builder),
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

Future<void> _setKeyboard(
  WidgetTester tester, {
  required double bottomBar,
  required double keyboard,
}) async {
  _applyInsets(tester, bottomBar: bottomBar, keyboard: keyboard);
  await tester.pump();
}

/// The three insets the way the engine derives them (`hooks.dart`): the
/// padding is what is left of the bar once the keyboard covers it.
void _applyInsets(
  WidgetTester tester, {
  required double bottomBar,
  required double keyboard,
}) {
  tester.view.viewPadding = FakeViewPadding(bottom: bottomBar * 3);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  tester.view.padding = FakeViewPadding(
    bottom: math.max(0, bottomBar - keyboard) * 3,
  );
}

bool _fieldHasFocus(WidgetTester tester) => tester
    .state<EditableTextState>(find.byType(EditableText))
    .widget
    .focusNode
    .hasFocus;

/// A sheet shaped like the app's forms: its controller lives in the state,
/// so building it again from scratch loses the text as well as the focus.
class _Form extends StatefulWidget {
  const _Form({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _value = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      children: [
        TextField(
          controller: _value,
          decoration: const InputDecoration(labelText: 'Valor'),
        ),
        const SizedBox(height: 16),
        const AppButton(label: 'Salvar', onPressed: null, expanded: true),
      ],
    );
  }
}
