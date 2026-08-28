import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/profile/domain/profile_copy.dart';
import 'package:meu_auto/features/profile/presentation/profile_screen.dart';

/// Perfil is a settings screen, and these are the two things that makes it
/// one: every setting shows its current value, and nothing on the page is a
/// form waiting to be filled in.
void main() {
  testWidgets('the e-mail is read-only and explained', (tester) async {
    await _pump(tester);

    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text(ProfileCopy.emailExplanation), findsOneWidget);
    expect(find.widgetWithText(TextField, 'E-mail'), findsNothing);
  });

  testWidgets('the name is shown as a value, not as an open form', (
    tester,
  ) async {
    var edits = 0;
    await _pump(tester, onEditName: () => edits++);

    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    // The permanent field and its Salvar button are what this screen stopped
    // being. Renaming yourself is rare; it does not get the top of the page.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Salvar nome'), findsNothing);

    await tester.tap(find.text('Nome'));
    await tester.pump();
    expect(edits, 1);
  });

  testWidgets('the settings are grouped, with the exits kept apart', (
    tester,
  ) async {
    await _pump(tester);

    for (final section in ['Conta', 'Veículos', 'Aparência', 'Sessão']) {
      expect(find.text(section), findsOneWidget, reason: section);
    }
    expect(
      tester.getTopLeft(find.text('Sair')).dy,
      greaterThan(tester.getTopLeft(find.text('Tema')).dy),
    );
  });

  testWidgets('the theme is one tap, and says which one is on', (
    tester,
  ) async {
    final chosen = <ThemeMode>[];
    await _pump(
      tester,
      themeMode: ThemeMode.dark,
      onThemeMode: chosen.add,
    );

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
          onLogout: () {},
          onDeleteAccount: () {},
        ),
      ),
    ),
  );
}
