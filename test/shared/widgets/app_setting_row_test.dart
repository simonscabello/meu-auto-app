import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_setting_row.dart';

/// A switch in a group of settings is a line like its neighbours: the whole
/// line is the target, a screen reader hears a switch and its state, and it
/// does not stand taller than the rows around it.
void main() {
  testWidgets('a tap anywhere on the line flips it', (tester) async {
    final changes = <bool>[];
    await _pump(tester, value: false, onChanged: changes.add);

    await tester.tap(find.text('Entrar com biometria'));
    expect(changes, [true]);
  });

  testWidgets('it is read as a switch with its state, not as a button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, value: true, onChanged: (_) {});

    final node = tester.getSemantics(
      find.bySemanticsLabel('Entrar com biometria'),
    );
    expect(
      node,
      isSemantics(
        label: 'Entrar com biometria',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isButton: false,
      ),
    );
    semantics.dispose();
  });

  testWidgets('held still while a change is on its way', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, value: false, onChanged: null);

    await tester.tap(find.text('Entrar com biometria'));
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Entrar com biometria')),
      isSemantics(hasEnabledState: true, isEnabled: false),
    );
    semantics.dispose();
  });

  testWidgets('as tall as the row above it', (tester) async {
    await _pump(tester, value: false, onChanged: (_) {});

    final row = tester.getSize(
      find.widgetWithText(AppSettingRow, 'Alterar senha'),
    );
    final toggle = tester.getSize(
      find.widgetWithText(AppSettingRow, 'Entrar com biometria'),
    );
    expect(toggle.height, row.height);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required bool value,
  required ValueChanged<bool>? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: AppGroup(
          title: 'Segurança',
          children: [
            AppSettingRow(
              label: 'Alterar senha',
              icon: Icons.lock_outline,
              onTap: () {},
            ),
            AppSettingRow.toggle(
              label: 'Entrar com biometria',
              icon: Icons.fingerprint,
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    ),
  );
}
