import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/push/push_registration.dart';
import 'package:meu_auto/core/session/session_manager.dart';
import 'package:meu_auto/core/session/session_tokens.dart';
import 'package:meu_auto/features/auth/data/auth_repository.dart';
import 'package:meu_auto/features/auth/data/biometric_lock_store.dart';
import 'package:meu_auto/features/auth/data/device_biometrics.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/profile_update.dart';
import 'package:meu_auto/features/auth/domain/session.dart';
import 'package:meu_auto/features/auth/domain/user.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthStatus>(AuthController.new);

/// How an attempt to open the locked session ended.
enum UnlockResult {
  /// In: the stored session still works, and it is the account that turned
  /// the lock on.
  unlocked,

  /// The prompt was dismissed or did not recognise the owner. Still locked,
  /// with both ways in on screen.
  notConfirmed,

  /// Too many failed attempts; the phone will not check again for a while.
  lockedOut,

  /// Confirmed, and then the server did not answer. The session is kept for
  /// the next try — it was never spent.
  unreachable,

  /// The server refused the session. It is gone; only the password gets back
  /// in.
  expired,
}

class AuthController extends AsyncNotifier<AuthStatus> {
  @override
  Future<AuthStatus> build() {
    final session = ref.watch(sessionManagerProvider);
    var closed = false;
    final subscription = session.sessionEnded.listen((_) {
      if (closed) {
        return;
      }
      state = const AsyncData(AuthLoggedOut());
    });
    ref.onDispose(() {
      closed = true;
      subscription.cancel();
    });
    return bootstrap();
  }

  Future<AuthStatus> bootstrap() async {
    final session = ref.read(sessionManagerProvider);
    SessionTokens? tokens;
    try {
      tokens = await session.readTokens();
    } on Object {
      await session.clear();
      return const AuthLoggedOut();
    }
    if (tokens == null) {
      return const AuthLoggedOut();
    }

    // With the lock on, the owner is checked before the session is: the
    // prompt comes first, then the network. See [unlock].
    if (await _enrolledUserId() != null) {
      return const AuthLocked();
    }

    try {
      final user = await ref.read(authRepositoryProvider).me();
      return AuthLoggedIn(user);
    } on ApiFailure catch (failure) {
      if (failure.code == ApiErrorCode.unauthorized) {
        await session.clear();
        return const AuthLoggedOut();
      }
      rethrow;
    }
  }

  /// Opens the stored session behind the biometric.
  ///
  /// **The biometric releases the session that is already on the phone; it
  /// never stores or replays a password.** After the prompt, `/me` goes out
  /// like any other request, so an access token that expired while the app
  /// was closed is renewed by the same single-flight refresh as everywhere
  /// else — and a refresh that never reached the server keeps the tokens.
  Future<UnlockResult> unlock() async {
    switch (await ref.read(deviceBiometricsProvider).confirm()) {
      case BiometricCheck.notConfirmed:
        return UnlockResult.notConfirmed;
      case BiometricCheck.lockedOut:
        return UnlockResult.lockedOut;
      case BiometricCheck.confirmed:
        break;
    }

    final User user;
    try {
      user = await ref.read(authRepositoryProvider).me();
    } on ApiFailure catch (failure) {
      if (failure.code == ApiErrorCode.unauthorized) {
        await _endLocalSession();
        return UnlockResult.expired;
      }
      return UnlockResult.unreachable;
    } on Object {
      return UnlockResult.unreachable;
    }

    // The stored session belongs to someone other than the account that
    // turned the lock on. Signing in as another account turns the lock off,
    // so nothing should get here; if something does, the lock must not open
    // for the wrong person.
    if (user.id != await _enrolledUserId()) {
      await _endLocalSession();
      return UnlockResult.expired;
    }
    state = AsyncData(AuthLoggedIn(user));
    return UnlockResult.unlocked;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .register(name: name, email: email, password: password);
    await _takeOverStoredSession(session.user);
    await _becomeLoggedIn(session);
  }

  /// [beforeEntering] runs after the server accepted the password and before
  /// the app moves on — the last moment the sign-in screen is still there to
  /// ask anything. Whatever it does, it cannot stop the sign-in.
  Future<void> login({
    required String email,
    required String password,
    Future<void> Function(User user)? beforeEntering,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    await _takeOverStoredSession(session.user);
    if (beforeEntering != null) {
      try {
        await beforeEntering(session.user);
      } on Object {
        // The invitation is optional; the account is not.
      }
    }
    await _becomeLoggedIn(session);
  }

  Future<void> logout() async {
    // First, while the session still authenticates: this phone stops
    // receiving this account's reminders. Afterwards the request could not be
    // made, and whoever signs in next here would be reminded of this car.
    await ref.read(pushRegistrationProvider).forgetThisDevice();

    final session = ref.read(sessionManagerProvider);
    final refreshToken = await session.peekRefreshToken();
    if (refreshToken != null) {
      try {
        await ref.read(authRepositoryProvider).logout(refreshToken);
      } on Object {
        // The UI always signs out, even when the server call fails.
      }
    }
    // "Sair" is the owner telling this phone to forget them, lock included.
    await _clearEnrollment();
    await _endLocalSession();
  }

  Future<void> updateName(String name) async {
    final user = await ref.read(authRepositoryProvider).updateMe(name: name);
    state = AsyncData(AuthLoggedIn(user));
  }

  Future<void> updateProfile(ProfileUpdate update) async {
    final user = await ref.read(authRepositoryProvider).updateProfile(update);
    state = AsyncData(AuthLoggedIn(user));
  }

  Future<void> setPhoto({
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .uploadPhoto(
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        );
    state = AsyncData(AuthLoggedIn(user));
  }

  /// The server answers 204, so the account is read again rather than
  /// patched by hand: the next response is the truth about the photo.
  Future<void> removePhoto() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.deletePhoto();
    final user = await repository.me();
    state = AsyncData(AuthLoggedIn(user));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
    await _becomeLoggedIn(session);
  }

  Future<void> deleteAccount({required String password}) async {
    await ref.read(authRepositoryProvider).deleteMe(password: password);
    await _clearEnrollment();
  }

  /// Drops tokens locally without calling logout. Used after a password reset,
  /// which already revoked every session on the server.
  ///
  /// The biometric lock stays: the same person is about to sign in again,
  /// and signing in as anyone else turns it off.
  Future<void> clearLocalSession() => _endLocalSession();

  /// Whether to show the invitation to [user] after a password sign-in: the
  /// phone can check a biometric, the lock is not already theirs, and they
  /// have not been asked before.
  Future<bool> shouldOfferBiometrics(User user) async {
    try {
      final store = ref.read(biometricLockStoreProvider);
      return await ref.read(deviceBiometricsProvider).isAvailable() &&
          await store.offeredUserId() != user.id &&
          await store.enrolledUserId() != user.id;
    } on Object {
      return false;
    }
  }

  Future<void> markBiometricsOffered(User user) async {
    try {
      await ref.read(biometricLockStoreProvider).markOffered(user.id);
    } on Object {
      // Asking again at the next sign-in is the worst that can happen.
    }
  }

  /// Null when this phone cannot check a biometric — there is then nothing
  /// to switch — otherwise whether the lock is on for [userId].
  Future<bool?> biometricSetting(String userId) async {
    if (!await ref.read(deviceBiometricsProvider).isAvailable()) {
      return null;
    }
    return await _enrolledUserId() == userId;
  }

  /// Turns the lock on for [user], once the phone confirms it is them.
  /// Turning it off asks nothing ([disableBiometrics]): whoever is holding
  /// the open app could simply use it.
  Future<BiometricCheck> enableBiometrics(User user) async {
    final check = await ref.read(deviceBiometricsProvider).confirm();
    if (check == BiometricCheck.confirmed) {
      await ref.read(biometricLockStoreProvider).enroll(user.id);
    }
    return check;
  }

  Future<void> disableBiometrics() => _clearEnrollment();

  /// A password sign-in replaces whatever session this phone still holds —
  /// typically one waiting behind the lock, when the owner chose "Usar e-mail
  /// e senha". That session is revoked rather than overwritten, which would
  /// leave its refresh token valid on the server for weeks. It is a separate
  /// session, so revoking it cannot touch the new one.
  ///
  /// The lock belongs to one account: another account signing in turns it
  /// off, and so does a phone whose biometrics are gone, where the lock could
  /// only ever send the owner to the password again.
  Future<void> _takeOverStoredSession(User incoming) async {
    String? previous;
    try {
      previous = await ref.read(sessionManagerProvider).peekRefreshToken();
    } on Object {
      previous = null;
    }
    if (previous != null) {
      unawaited(_revoke(previous));
    }

    final enrolled = await _enrolledUserId();
    if (enrolled == null) return;
    if (enrolled != incoming.id ||
        !await ref.read(deviceBiometricsProvider).isAvailable()) {
      await _clearEnrollment();
    }
  }

  /// Not awaited by the sign-in: the network just worked, but a slow answer
  /// here must not hold the owner at the door.
  Future<void> _revoke(String refreshToken) async {
    try {
      await ref.read(authRepositoryProvider).logout(refreshToken);
    } on Object {
      // Revoking is a courtesy to the server; the new session does not need it.
    }
  }

  /// Failing to read the lock opens nothing that reading the session would
  /// not: the tokens sit in the same storage.
  Future<String?> _enrolledUserId() async {
    try {
      return await ref.read(biometricLockStoreProvider).enrolledUserId();
    } on Object {
      return null;
    }
  }

  Future<void> _clearEnrollment() async {
    try {
      await ref.read(biometricLockStoreProvider).clearEnrollment();
    } on Object {
      // The next sign-in by another account clears it again.
    }
  }

  Future<void> _endLocalSession() async {
    await ref.read(sessionManagerProvider).clear();
    state = const AsyncData(AuthLoggedOut());
  }

  Future<void> _becomeLoggedIn(Session session) async {
    await ref.read(sessionManagerProvider).save(session.tokens);
    state = AsyncData(AuthLoggedIn(session.user));
  }
}
