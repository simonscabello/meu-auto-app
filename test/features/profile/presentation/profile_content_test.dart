import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/profile/domain/profile_copy.dart';
import 'package:meu_auto/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('the e-mail is read-only and explained', (tester) async {
    final name = TextEditingController(text: 'Ana');
    addTearDown(name.dispose);

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
            nameController: name,
            nameError: null,
            banner: null,
            savingName: false,
            nameDirty: false,
            loggingOut: false,
            themeMode: ThemeMode.system,
            onSaveName: () {},
            onNameChanged: () {},
            onThemeMode: (_) {},
            onVehicles: () {},
            onLogout: () {},
            onDeleteAccount: () {},
          ),
        ),
      ),
    );

    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text(ProfileCopy.emailExplanation), findsOneWidget);
    expect(find.widgetWithText(TextField, 'E-mail'), findsNothing);
  });
}
