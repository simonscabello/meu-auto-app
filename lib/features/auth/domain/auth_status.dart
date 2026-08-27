import 'package:meu_auto/features/auth/domain/user.dart';

sealed class AuthStatus {
  const AuthStatus();
}

final class AuthUnknown extends AuthStatus {
  const AuthUnknown();
}

final class AuthLoggedOut extends AuthStatus {
  const AuthLoggedOut();
}

final class AuthLoggedIn extends AuthStatus {
  const AuthLoggedIn(this.user);

  final User user;
}
