import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/session/session_tokens.dart';

void main() {
  final sessionJson = {
    'user': {
      'id': '11111111-1111-1111-1111-111111111111',
      'name': 'Ana',
      'email': 'ana@example.com',
      'created_at': '2026-01-15T12:00:00Z',
    },
    'token_type': 'Bearer',
    'access_token': 'access-secret',
    'expires_at': '2026-08-26T16:30:00.000Z',
    'refresh_token': 'refresh-secret',
    'refresh_expires_at': '2026-09-25T16:15:00.000Z',
  };

  test('fromJson reads Session token fields and ignores user', () {
    final tokens = SessionTokens.fromJson(sessionJson);

    expect(tokens.accessToken, 'access-secret');
    expect(tokens.refreshToken, 'refresh-secret');
    expect(
      tokens.expiresAt,
      DateTime.parse('2026-08-26T16:30:00.000Z').toLocal(),
    );
    expect(
      tokens.refreshExpiresAt,
      DateTime.parse('2026-09-25T16:15:00.000Z').toLocal(),
    );
  });

  test(
    'isAccessExpiringWithin is true only when remaining time is under the window',
    () {
      final now = DateTime.utc(2026, 8, 26, 16, 0);
      final tokens = SessionTokens(
        accessToken: 'a',
        expiresAt: now.add(const Duration(seconds: 30)),
        refreshToken: 'r',
        refreshExpiresAt: now.add(const Duration(days: 30)),
      );

      expect(
        tokens.isAccessExpiringWithin(const Duration(seconds: 60), now: now),
        isTrue,
      );
      expect(
        tokens.isAccessExpiringWithin(const Duration(seconds: 30), now: now),
        isFalse,
      );
      expect(
        tokens.isAccessExpiringWithin(const Duration(seconds: 10), now: now),
        isFalse,
      );
    },
  );

  test(
    'already-expired access token is treated as expiring within any window',
    () {
      final now = DateTime.utc(2026, 8, 26, 16, 0);
      final tokens = SessionTokens(
        accessToken: 'a',
        expiresAt: now.subtract(const Duration(seconds: 1)),
        refreshToken: 'r',
        refreshExpiresAt: now.add(const Duration(days: 30)),
      );

      expect(
        tokens.isAccessExpiringWithin(const Duration(seconds: 60), now: now),
        isTrue,
      );
    },
  );

  test('toString does not include token values', () {
    final tokens = SessionTokens.fromJson(sessionJson);
    final text = tokens.toString();

    expect(text, isNot(contains('access-secret')));
    expect(text, isNot(contains('refresh-secret')));
  });
}
