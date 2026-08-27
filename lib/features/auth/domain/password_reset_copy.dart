abstract final class PasswordResetCopy {
  /// Neutral: the same sentence whether or not the address has an account.
  static const requestAccepted =
      'Se existir uma conta com esse e-mail, enviamos o link';

  static const linkLifetime = 'O link vale 1 hora e só pode ser usado uma vez.';

  static const sessionsEnded =
      'Senha redefinida. Todas as sessões foram encerradas. Entre com a nova senha.';
}
