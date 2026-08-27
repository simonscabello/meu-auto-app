import 'package:meu_auto/core/session/session_tokens.dart';
import 'package:meu_auto/features/auth/domain/user.dart';

final class Session {
  const Session({required this.user, required this.tokens});

  final User user;
  final SessionTokens tokens;

  factory Session.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return Session(
      user: User.fromJson(Map<String, dynamic>.from(rawUser as Map)),
      tokens: SessionTokens.fromJson(json),
    );
  }

  @override
  String toString() => 'Session(user: $user)';
}
