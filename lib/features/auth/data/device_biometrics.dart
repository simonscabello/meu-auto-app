import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:meu_auto/features/auth/domain/biometric_copy.dart';

final deviceBiometricsProvider = Provider<DeviceBiometrics>((ref) {
  return LocalAuthBiometrics();
});

/// Whether the phone can check a biometric right now. Perfil and the sign-in
/// screen decide from this whether their biometric line exists at all.
final biometricsAvailableProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(deviceBiometricsProvider).isAvailable();
});

/// What one biometric check came to.
enum BiometricCheck {
  confirmed,

  /// Dismissed, not recognised, or gone at the moment it was asked. The
  /// password is still the way in, so none of these is an error to show.
  notConfirmed,

  /// Too many failed attempts. The phone refuses biometrics for a while, and
  /// asking again right away returns at once without showing anything.
  lockedOut,
}

/// The phone's own biometric check — a fingerprint or a face — and nothing
/// more. It unlocks nothing by itself: what a confirmation opens is the
/// caller's business.
abstract interface class DeviceBiometrics {
  /// The hardware exists and at least one biometric is enrolled.
  Future<bool> isAvailable();

  /// Opens the system prompt.
  Future<BiometricCheck> confirm();
}

final class LocalAuthBiometrics implements DeviceBiometrics {
  LocalAuthBiometrics({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Android and iOS. The web build never touches the plugin, which has no
  /// implementation there; neither would a desktop one.
  static bool get runsOnThisPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> isAvailable() async {
    if (!runsOnThisPlatform) return false;
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<BiometricCheck> confirm() async {
    if (!await isAvailable()) return BiometricCheck.notConfirmed;
    try {
      final confirmed = await _auth.authenticate(
        localizedReason: BiometricCopy.promptReason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: BiometricCopy.promptTitle,
            signInHint: BiometricCopy.promptSubtitle,
            cancelButton: BiometricCopy.promptCancel,
          ),
          // An empty fallback title hides iOS's own "Enter Password", which
          // a biometric-only check cannot honour. Our way to the password is
          // on the screen behind the prompt.
          IOSAuthMessages(
            cancelButton: BiometricCopy.promptCancel,
            localizedFallbackTitle: '',
          ),
        ],
        // The device PIN would open the app to anyone who knows the PIN,
        // which is not what the owner turned on.
        biometricOnly: true,
        // Opening an app is not a payment: a recognised face goes straight
        // in, without Android's extra "Confirmar" tap.
        sensitiveTransaction: false,
        // A call arriving mid-prompt must not count as a cancellation.
        persistAcrossBackgrounding: true,
      );
      return confirmed ? BiometricCheck.confirmed : BiometricCheck.notConfirmed;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => BiometricCheck.lockedOut,
        _ => BiometricCheck.notConfirmed,
      };
    } on Object {
      return BiometricCheck.notConfirmed;
    }
  }
}
