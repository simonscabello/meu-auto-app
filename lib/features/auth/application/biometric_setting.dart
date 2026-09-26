import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/data/device_biometrics.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';

/// Perfil's switch. Null when the phone cannot check a biometric, and then
/// the row is not drawn at all; otherwise whether the lock is on for the
/// signed-in account.
final biometricSettingProvider =
    AsyncNotifierProvider.autoDispose<BiometricSettingController, bool?>(
      BiometricSettingController.new,
    );

class BiometricSettingController extends AutoDisposeAsyncNotifier<bool?> {
  @override
  Future<bool?> build() async {
    // Keyed on the account, not the whole status: renaming yourself is a new
    // status and must not re-ask the phone about its sensors.
    final userId = ref.watch(
      authControllerProvider.select(
        (value) => switch (value.valueOrNull) {
          AuthLoggedIn(:final user) => user.id,
          _ => null,
        },
      ),
    );
    if (userId == null) return null;
    return ref.read(authControllerProvider.notifier).biometricSetting(userId);
  }

  /// Turning the lock on asks the phone first; turning it off does not.
  /// Returns what the phone answered, or null when nothing was asked.
  Future<BiometricCheck?> set({required bool on}) async {
    final status = ref.read(authControllerProvider).valueOrNull;
    if (status is! AuthLoggedIn) return null;
    final auth = ref.read(authControllerProvider.notifier);
    if (!on) {
      await auth.disableBiometrics();
      state = const AsyncData(false);
      return null;
    }
    final check = await auth.enableBiometrics(status.user);
    if (check == BiometricCheck.confirmed) {
      state = const AsyncData(true);
    }
    return check;
  }
}
