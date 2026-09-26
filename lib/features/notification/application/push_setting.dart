import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/push/push_device.dart';
import 'package:meu_auto/core/push/push_registration.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';

/// Perfil's "Avisos no celular", as it stands on this phone.
final class PushSetting {
  const PushSetting({required this.enabled, required this.blocked});

  /// The owner wants reminders here (they did not turn them off in Perfil).
  final bool enabled;

  /// Wanted, and Android refuses to show them — the notification permission
  /// was denied or later revoked in the phone's settings.
  final bool blocked;
}

/// Null when this phone cannot be reminded at all — the web, or a build
/// without Firebase — and then Perfil has no row.
final pushSettingProvider =
    AsyncNotifierProvider.autoDispose<PushSettingController, PushSetting?>(
      PushSettingController.new,
    );

class PushSettingController extends AutoDisposeAsyncNotifier<PushSetting?> {
  @override
  Future<PushSetting?> build() async {
    final userId = ref.watch(
      authControllerProvider.select(
        (value) => switch (value.valueOrNull) {
          AuthLoggedIn(:final user) => user.id,
          _ => null,
        },
      ),
    );
    if (userId == null) return null;

    final device = ref.watch(pushDeviceProvider);
    if (!device.isSupported) return null;
    await device.init();
    if (!device.isReady) return null;

    final enabled = await ref.read(pushRegistrationProvider).isEnabled(userId);
    final permitted = await device.hasPermission();
    return PushSetting(enabled: enabled, blocked: enabled && !permitted);
  }

  /// On registers this phone and, if Android has not allowed notifications,
  /// asks — the owner just said they want them. Off forgets the phone.
  Future<void> set({required bool on}) async {
    final status = ref.read(authControllerProvider).valueOrNull;
    if (status is! AuthLoggedIn) return;
    final device = ref.read(pushDeviceProvider);

    await ref
        .read(pushRegistrationProvider)
        .setEnabled(status.user.id, enabled: on);

    var permitted = await device.hasPermission();
    if (on && !permitted) permitted = await device.requestPermission();
    state = AsyncData(PushSetting(enabled: on, blocked: on && !permitted));
  }
}
