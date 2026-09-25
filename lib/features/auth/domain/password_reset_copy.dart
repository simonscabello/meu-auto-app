abstract final class PasswordResetCopy {
  /// Neutral: the same sentence whether or not the address has an account.
  static const requestAccepted =
      'Se existir uma conta com esse e-mail, enviamos o link';

  static const linkLifetime = 'O link vale 1 hora e só pode ser usado uma vez.';

  /// Said before the new password is typed, not after: it is a consequence
  /// to weigh, not news.
  static const signsOutEverywhere =
      'Ao redefinir, todos os aparelhos saem da conta.';
}
