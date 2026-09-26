import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something good to confirm on the sign-in screen, once, as a snack bar —
/// "Conta excluída". Set by a screen that is gone by the time sign-in opens.
final loginNoticeProvider = StateProvider<String?>((ref) => null);

/// Why the owner is on the sign-in screen when it was not their choice —
/// today only "Sua sessão expirou", from the unlock screen. It sits in the
/// form's banner until the next attempt, because it explains the password
/// they are about to type; a snack bar would be gone before they started.
final loginProblemProvider = StateProvider<String?>((ref) => null);
