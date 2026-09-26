/// The app's words about the push reminders. The reminders' own text is
/// written by the server, because the phone draws them (meu-auto-backend,
/// internal/notification/text.go).
abstract final class ReminderCopy {
  /// Perfil.
  static const groupTitle = 'Lembretes';
  static const settingLabel = 'Avisos no celular';

  /// Under the switch: when a reminder comes and about what — the owner
  /// decides with the fact in front of them.
  static const note =
      'Às 9h, quando manutenção, IPVA, licenciamento ou seguro está perto de '
      'vencer ou venceu. Vale só neste aparelho.';

  /// The switch is on and Android refuses to show anything. Said, because
  /// otherwise the switch stays on, nothing arrives, and the app looks broken.
  static const blocked =
      'O Android está bloqueando os avisos do Meu Auto. Libere em '
      'Configurações › Apps › Meu Auto › Notificações.';
}
