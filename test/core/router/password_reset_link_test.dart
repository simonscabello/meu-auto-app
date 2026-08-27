import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/router/password_reset_link.dart';

void main() {
  group('passwordResetTokenOf', () {
    test('reads the token from the query', () {
      expect(
        passwordResetTokenOf(
          Uri.parse('${AppRoutes.passwordResetConfirm}?token=abc123'),
        ),
        'abc123',
      );
    });

    test('reads the token from the custom-scheme deep link', () {
      expect(
        passwordResetTokenOf(Uri.parse('meuauto://redefinir-senha?token=xyz')),
        'xyz',
      );
    });

    test('returns null when the query has no token', () {
      expect(
        passwordResetTokenOf(Uri.parse(AppRoutes.passwordResetConfirm)),
        isNull,
      );
      expect(
        passwordResetTokenOf(Uri.parse('meuauto://redefinir-senha')),
        isNull,
      );
    });
  });

  group('rewritePasswordResetDeepLink', () {
    test('turns the custom-scheme URI into the in-app path', () {
      expect(
        rewritePasswordResetDeepLink(
          Uri.parse('meuauto://redefinir-senha?token=abc123'),
        ),
        '${AppRoutes.passwordResetConfirm}?token=abc123',
      );
    });

    test('keeps an already-canonical path unchanged', () {
      expect(
        rewritePasswordResetDeepLink(
          Uri.parse('${AppRoutes.passwordResetConfirm}?token=abc123'),
        ),
        isNull,
      );
    });
  });
}
