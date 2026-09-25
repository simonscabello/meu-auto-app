import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/profile/domain/profile_copy.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/profile/presentation/profile_screen.dart';
import 'package:meu_auto/shared/widgets/app_setting_row.dart';

/// Perfil is who is signed in, then a settings screen, and these are the
/// things that make it one: every setting shows its current value, and
/// nothing on the page is a form waiting to be filled in.
void main() {
  testWidgets('the header is the person: initial, name and e-mail', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    // The name heads the page and is also the value of its setting row.
    expect(find.text('Ana'), findsNWidgets(2));
  });

  testWidgets('the e-mail is read-only and explained', (tester) async {
    await _pump(tester);

    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text(ProfileCopy.emailNote), findsOneWidget);
    expect(find.widgetWithText(TextField, 'E-mail'), findsNothing);
    expect(find.widgetWithText(AppSettingRow, 'E-mail'), findsNothing);
  });

  testWidgets('the name is shown as a value, not as an open form', (
    tester,
  ) async {
    var edits = 0;
    await _pump(tester, onEditName: () => edits++);

    expect(find.text('Nome'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(AppSettingRow, 'Nome'),
        matching: find.text('Ana'),
      ),
      findsOneWidget,
    );
    // The permanent field and its Salvar button are what this screen stopped
    // being. Renaming yourself is rare; it does not get the top of the page.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Salvar nome'), findsNothing);

    await tester.tap(find.text('Nome'));
    await tester.pump();
    expect(edits, 1);
  });

  testWidgets('password change is available from account settings', (
    tester,
  ) async {
    var changes = 0;
    await _pump(tester, onChangePassword: () => changes++);

    await tester.tap(find.text('Alterar senha'));
    await tester.pump();

    expect(changes, 1);
  });

  testWidgets('the settings are grouped, with the exits kept apart and last', (
    tester,
  ) async {
    await _pump(tester);

    for (final section in ['Conta', 'Veículos', 'Aparência']) {
      expect(find.text(section), findsOneWidget, reason: section);
    }
    await tester.ensureVisible(find.text('Excluir minha conta'));
    expect(
      tester.getTopLeft(find.text('Sair')).dy,
      greaterThan(tester.getTopLeft(find.text('Sistema')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Excluir minha conta')).dy,
      greaterThan(tester.getTopLeft(find.text('Sair')).dy),
    );
  });

  // "Sair" happens in place, after a confirmation; it does not open a screen,
  // so it does not carry the chevron that says it would.
  testWidgets('Sair has no chevron; Excluir minha conta does', (tester) async {
    var logouts = 0;
    await _pump(tester, onLogout: () => logouts++);

    Finder chevronIn(String label) => find.descendant(
      of: find.widgetWithText(AppSettingRow, label),
      matching: find.byIcon(Icons.chevron_right),
    );
    expect(chevronIn('Sair'), findsNothing);
    expect(chevronIn('Excluir minha conta'), findsOneWidget);

    await tester.ensureVisible(find.text('Sair'));
    await tester.tap(find.text('Sair'));
    await tester.pump();
    expect(logouts, 1);
  });

  testWidgets('only account deletion is painted as destructive', (
    tester,
  ) async {
    await _pump(tester);

    final rows = tester.widgetList<AppSettingRow>(find.byType(AppSettingRow));
    expect(
      [
        for (final row in rows)
          if (row.destructive) row.label,
      ],
      ['Excluir minha conta'],
    );
  });

  testWidgets('the theme is one tap, and says which one is on', (tester) async {
    final chosen = <ThemeMode>[];
    await _pump(tester, themeMode: ThemeMode.dark, onThemeMode: chosen.add);

    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);

    await tester.tap(find.text('Claro'));
    await tester.pump();
    expect(chosen, [ThemeMode.light]);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.system,
  VoidCallback? onEditName,
  VoidCallback? onChangePassword,
  VoidCallback? onLogout,
  ValueChanged<ThemeMode>? onThemeMode,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ProfileContent(
          user: User(
            id: '11111111-1111-1111-1111-111111111111',
            name: 'Ana',
            email: 'ana@example.com',
            createdAt: DateTime.parse('2026-01-15T12:00:00Z').toLocal(),
          ),
          themeMode: themeMode,
          onEditName: onEditName ?? () {},
          onThemeMode: onThemeMode ?? (_) {},
          onVehicles: () {},
          onChangePassword: onChangePassword ?? () {},
          onLogout: onLogout ?? () {},
          onDeleteAccount: () {},
        ),
      ),
    ),
  );
}
