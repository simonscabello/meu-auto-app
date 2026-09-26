/// The words around biometric sign-in, in one place so the screens, the
/// system prompt and the tests say the same thing.
abstract final class BiometricCopy {
  /// The system prompt. The plugin's defaults are English ("Authentication
  /// required", "Cancel"), and on Android they sit right beside our own
  /// words, so every line of it is replaced. Android shows the title, the
  /// subtitle and the reason; iOS shows the reason under Touch ID.
  static const promptTitle = 'Meu Auto';
  static const promptSubtitle = 'Confirme que é você';
  static const promptReason = 'Use a biometria cadastrada neste aparelho.';
  static const promptCancel = 'Cancelar';

  /// Under the mark on the unlock screen, once the prompt was dismissed.
  static const unlockAsk = 'Confirme que é você para continuar.';
  static const unlockButton = 'Entrar com biometria';
  static const usePassword = 'Usar e-mail e senha';

  /// The biometric was confirmed and the server did not answer. The password
  /// is deliberately not offered here: it needs the same server.
  static const unreachable =
      'Não foi possível falar com o servidor. Confira a internet e tente de novo.';

  /// Too many failed attempts: the phone refuses biometrics for a while, and
  /// tapping the button again would do nothing at all.
  static const lockedOut =
      'Muitas tentativas. Espere um pouco ou entre com e-mail e senha.';

  /// The server refused the stored session. Said on the sign-in screen, so it
  /// does not look as if the app signed the owner out on its own.
  static const expired = 'Sua sessão expirou. Entre com seu e-mail e senha.';

  /// The invitation, once per account, after a password sign-in.
  static const offerTitle = 'Entrar mais rápido da próxima vez?';
  static const offerMessage =
      'Use a biometria deste aparelho para abrir o Meu Auto sem digitar a senha.';
  static const offerAccept = 'Usar biometria';
  static const offerDecline = 'Agora não';

  /// Perfil.
  static const settingLabel = 'Entrar com biometria';
  static const settingNote = 'A biometria vale só neste aparelho.';
  static const enabled =
      'Pronto. Da próxima vez, o Meu Auto abre com a biometria.';
  static const notConfirmed = 'Biometria não confirmada.';
  static const lockedOutSetting =
      'Muitas tentativas. Espere um pouco e tente de novo.';

  /// The invitation was accepted and the prompt then failed. The owner is on
  /// their way into the app, so the message says where to try again.
  static const notConfirmedLater =
      'Biometria não confirmada. Dá para ligar depois em Perfil.';
}
