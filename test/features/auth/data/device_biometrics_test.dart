import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:meu_auto/features/auth/data/device_biometrics.dart';
import 'package:meu_auto/features/auth/domain/biometric_copy.dart';

/// The one place the plugin is called, and what it is called with.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'confirms through a biometric-only prompt, worded in Portuguese',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final plugin = _FakeLocalAuth(result: true);

      expect(
        await LocalAuthBiometrics(auth: plugin).confirm(),
        BiometricCheck.confirmed,
      );

      expect(plugin.reason, BiometricCopy.promptReason);
      // The device PIN must not open the app, and a recognised face goes in
      // without a second tap.
      expect(plugin.biometricOnly, isTrue);
      expect(plugin.sensitiveTransaction, isFalse);
      expect(plugin.persistAcrossBackgrounding, isTrue);
      // The plugin's own words are English; none of them may reach the screen.
      final android = plugin.messages!.whereType<AndroidAuthMessages>().single;
      expect(android.signInTitle, BiometricCopy.promptTitle);
      expect(android.signInHint, BiometricCopy.promptSubtitle);
      expect(android.cancelButton, BiometricCopy.promptCancel);
      final ios = plugin.messages!.whereType<IOSAuthMessages>().single;
      expect(ios.cancelButton, BiometricCopy.promptCancel);
      expect(ios.localizedFallbackTitle, isEmpty);
    },
  );

  test('a dismissed prompt is not an error', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(
      await LocalAuthBiometrics(auth: _FakeLocalAuth(result: false)).confirm(),
      BiometricCheck.notConfirmed,
    );
    expect(
      await LocalAuthBiometrics(
        auth: _FakeLocalAuth(
          error: const LocalAuthException(
            code: LocalAuthExceptionCode.userCanceled,
          ),
        ),
      ).confirm(),
      BiometricCheck.notConfirmed,
    );
  });

  test('too many attempts is told apart, both kinds of it', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    for (final code in [
      LocalAuthExceptionCode.temporaryLockout,
      LocalAuthExceptionCode.biometricLockout,
    ]) {
      expect(
        await LocalAuthBiometrics(
          auth: _FakeLocalAuth(error: LocalAuthException(code: code)),
        ).confirm(),
        BiometricCheck.lockedOut,
        reason: code.name,
      );
    }
  });

  test('hardware with nothing enrolled is not available, and is never '
      'prompted', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final plugin = _FakeLocalAuth(enrolled: const [], result: true);
    final biometrics = LocalAuthBiometrics(auth: plugin);

    expect(await biometrics.isAvailable(), isFalse);
    expect(await biometrics.confirm(), BiometricCheck.notConfirmed);
    expect(plugin.prompts, 0);
  });

  test('a plugin that throws while checking counts as unavailable', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(
      await LocalAuthBiometrics(
        auth: _FakeLocalAuth(checkError: StateError('no plugin')),
      ).isAvailable(),
      isFalse,
    );
  });

  test('off Android and iOS the plugin is never touched', () async {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final plugin = _FakeLocalAuth(result: true);
      final biometrics = LocalAuthBiometrics(auth: plugin);

      expect(await biometrics.isAvailable(), isFalse, reason: platform.name);
      expect(await biometrics.confirm(), BiometricCheck.notConfirmed);
      expect(plugin.touched, isFalse, reason: platform.name);
    }
  });
}

final class _FakeLocalAuth extends LocalAuthentication {
  _FakeLocalAuth({
    this.enrolled = const [BiometricType.strong],
    this.result = false,
    this.error,
    this.checkError,
  });

  final List<BiometricType> enrolled;
  final bool result;
  final Object? error;
  final Object? checkError;

  bool touched = false;
  int prompts = 0;
  String? reason;
  Iterable<AuthMessages>? messages;
  bool? biometricOnly;
  bool? sensitiveTransaction;
  bool? persistAcrossBackgrounding;

  @override
  Future<bool> get canCheckBiometrics async {
    touched = true;
    final failure = checkError;
    if (failure != null) throw failure;
    return true;
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    touched = true;
    return enrolled;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    touched = true;
    prompts++;
    reason = localizedReason;
    messages = authMessages;
    this.biometricOnly = biometricOnly;
    this.sensitiveTransaction = sensitiveTransaction;
    this.persistAcrossBackgrounding = persistAcrossBackgrounding;
    final failure = error;
    if (failure != null) throw failure;
    return result;
  }
}
