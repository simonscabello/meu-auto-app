import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/session/session_tokens.dart';
import 'package:meu_auto/features/auth/domain/session.dart';
import 'package:meu_auto/features/auth/domain/user.dart';

import '../support/fixtures.dart';
import '../support/parse.dart';

void main() {
  final userJson = loadFixture('me_get.json');
  final sessionJson = loadFixture('auth_login.json');

  group('User.fromJson', () {
    test('parses a complete me response', () {
      final user = User.fromJson(userJson);

      expect(user.id, '11111111-1111-1111-1111-111111111111');
      expect(user.name, 'Ana');
      expect(user.email, 'ana@example.com');
      expect(user.createdAt, DateTime.parse('2026-01-15T12:00:00Z').toLocal());
    });

    test('fails clearly when a required field is missing', () {
      expect(
        () => User.fromJson(withoutKey(userJson, 'email')),
        throwsMissingRequired,
      );
      expect(
        () => User.fromJson(withoutKey(userJson, 'id')),
        throwsMissingRequired,
      );
    });
  });

  group('Session.fromJson', () {
    test('parses a complete login response', () {
      final session = Session.fromJson(sessionJson);

      expect(session.user.name, 'Ana');
      expect(session.tokens.accessToken, 'access-secret');
      expect(session.tokens.refreshToken, 'refresh-secret');
    });

    test('fails clearly when user or a token field is missing', () {
      expect(
        () => Session.fromJson(withoutKey(sessionJson, 'user')),
        throwsMissingRequired,
      );
      expect(
        () => Session.fromJson(withoutKey(sessionJson, 'access_token')),
        throwsMissingRequired,
      );
    });
  });

  group('SessionTokens.fromJson', () {
    test('reads token fields out of the login envelope', () {
      final tokens = SessionTokens.fromJson(sessionJson);

      expect(tokens.accessToken, 'access-secret');
      expect(
        tokens.expiresAt,
        DateTime.parse('2026-08-26T16:30:00.000Z').toLocal(),
      );
    });

    test('fails clearly when a required token field is missing', () {
      expect(
        () => SessionTokens.fromJson(withoutKey(sessionJson, 'refresh_token')),
        throwsMissingRequired,
      );
    });
  });
}
