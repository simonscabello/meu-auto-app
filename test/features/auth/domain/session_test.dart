import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/auth/domain/session.dart';
import 'package:meu_auto/features/auth/domain/user.dart';

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

  test('User.fromJson reads id, name, email and RFC 3339 createdAt', () {
    final user = User.fromJson(sessionJson['user']! as Map<String, dynamic>);

    expect(user.id, '11111111-1111-1111-1111-111111111111');
    expect(user.name, 'Ana');
    expect(user.email, 'ana@example.com');
    expect(user.createdAt, DateTime.parse('2026-01-15T12:00:00Z').toLocal());
  });

  test('Session.fromJson reads user and tokens', () {
    final session = Session.fromJson(sessionJson);

    expect(session.user.name, 'Ana');
    expect(session.user.email, 'ana@example.com');
    expect(session.tokens.accessToken, 'access-secret');
    expect(session.tokens.refreshToken, 'refresh-secret');
    expect(
      session.tokens.expiresAt,
      DateTime.parse('2026-08-26T16:30:00.000Z').toLocal(),
    );
    expect(
      session.tokens.refreshExpiresAt,
      DateTime.parse('2026-09-25T16:15:00.000Z').toLocal(),
    );
  });

  test('Session.toString does not include token values', () {
    final session = Session.fromJson(sessionJson);
    final text = session.toString();

    expect(text, isNot(contains('access-secret')));
    expect(text, isNot(contains('refresh-secret')));
    expect(text, contains('Ana'));
  });
}
