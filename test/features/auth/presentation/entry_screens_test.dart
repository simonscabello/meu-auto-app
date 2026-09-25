import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/auth/domain/password_reset_copy.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/auth/presentation/auth_password_field.dart';
import 'package:meu_auto/features/auth/presentation/login_screen.dart';
import 'package:meu_auto/features/auth/presentation/password_reset_request_screen.dart';
import 'package:meu_auto/features/auth/presentation/register_screen.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_wordmark.dart';

/// The front door and the two screens beside it: one filled button each, the
/// rest as text, and nothing said that the app does not do.
void main() {
  group('login', () {
    testWidgets('has no app bar; the mark and one line head the page', (
      tester,
    ) async {
      await _pump(tester, const LoginScreen());

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(AppWordmark), findsOneWidget);
      expect(find.text(loginTagline), findsOneWidget);
    });

    testWidgets('Entrar is the one primary button; the rest are text', (
      tester,
    ) async {
      await _pump(tester, const LoginScreen());

      final entrar = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Entrar'),
      );
      expect(entrar.variant, AppButtonVariant.primary);
      expect(entrar.expanded, isTrue);
      expect(_primaryButtons(tester), hasLength(1));

      for (final label in ['Esqueci minha senha', 'Criar conta']) {
        final button = tester.widget<AppButton>(
          find.widgetWithText(AppButton, label),
        );
        expect(button.variant, AppButtonVariant.tertiary, reason: label);
      }
    });

    testWidgets('the fields carry no decoration of their own', (tester) async {
      await _pump(tester, const LoginScreen());

      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.decoration?.prefixIcon, isNull);
      }
    });
  });

  group('register', () {
    testWidgets('says the task, and leads back to the sign-in', (tester) async {
      await _pump(tester, const RegisterScreen());

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Criar conta'),
        ),
        findsOneWidget,
      );
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text(newPasswordHint), findsOneWidget);
      expect(_primaryButtons(tester), hasLength(1));
    });
  });

  group('password reset request', () {
    testWidgets('explains the link once and asks for the e-mail', (
      tester,
    ) async {
      await _pump(tester, const PasswordResetRequestScreen());

      expect(find.text(PasswordResetCopy.linkLifetime), findsOneWidget);
      expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(_primaryButtons(tester), hasLength(1));
    });
  });

  group('form banner', () {
    testWidgets('is announced to a screen reader as an error', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: AuthFormBanner(message: 'Sem conexão com a internet.'),
          ),
        ),
      );

      expect(find.text('Sem conexão com a internet.'), findsOneWidget);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Erro: Sem conexão com a internet.'),
        ),
        isSemantics(
          label: 'Erro: Sem conexão com a internet.',
          isLiveRegion: true,
        ),
      );
      semantics.dispose();
    });
  });
}

List<AppButton> _primaryButtons(WidgetTester tester) => [
  for (final button in tester.widgetList<AppButton>(find.byType(AppButton)))
    if (button.variant == AppButtonVariant.primary) button,
];

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
      ],
      child: MaterialApp(theme: AppTheme.light, home: screen),
    ),
  );
  await tester.pump();
}
