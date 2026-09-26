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

/// A session is stored on this phone and biometric sign-in is on: nothing
/// opens until the owner confirms it is them. Nothing about the session has
/// been checked yet — the prompt comes before the network.
final class AuthLocked extends AuthStatus {
  const AuthLocked();
}

final class AuthLoggedIn extends AuthStatus {
  const AuthLoggedIn(this.user);

  final User user;
}
