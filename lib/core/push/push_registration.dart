import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/core/push/push_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pushOptOutStoreProvider = Provider<PushOptOutStore>((ref) {
  return SharedPreferencesPushOptOut();
});

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  return PushRegistration(
    api: ref.watch(apiClientProvider),
    device: ref.watch(pushDeviceProvider),
    optOut: ref.watch(pushOptOutStoreProvider),
  );
});

/// Which accounts turned the reminders off on this phone.
///
/// Per account, like the biometric lock: another person signing in on the
/// same phone must not inherit somebody else's "no".
abstract interface class PushOptOutStore {
  Future<bool> isOptedOut(String userId);
  Future<void> setOptedOut(String userId, {required bool optedOut});
}

final class SharedPreferencesPushOptOut implements PushOptOutStore {
  SharedPreferencesPushOptOut({this.prefs});

  static const key = 'push_opted_out_user_ids';

  final SharedPreferences? prefs;

  Future<SharedPreferences> _prefs() async =>
      prefs ?? await SharedPreferences.getInstance();

  @override
  Future<bool> isOptedOut(String userId) async {
    final stored = await _prefs();
    return (stored.getStringList(key) ?? const []).contains(userId);
  }

  @override
  Future<void> setOptedOut(String userId, {required bool optedOut}) async {
    final stored = await _prefs();
    final ids = {...stored.getStringList(key) ?? const <String>[]};
    optedOut ? ids.add(userId) : ids.remove(userId);
    await stored.setStringList(key, ids.toList());
  }
}

/// Tells the server which phone the signed-in account's reminders go to.
///
/// Every call is best-effort and silent: a phone not reminded is a smaller
/// failure than a sign-in, a sign-out or a switch that breaks, and the next
/// sign-in registers again.
final class PushRegistration {
  PushRegistration({
    required this.api,
    required this.device,
    required this.optOut,
  });

  static const platform = 'android';

  final ApiClient api;
  final PushDevice device;
  final PushOptOutStore optOut;

  /// Registers this phone for [userId]'s reminders — unless they turned the
  /// reminders off here, in Perfil.
  Future<void> register(String userId) async {
    if (!device.isReady || await optOut.isOptedOut(userId)) return;
    final token = await device.currentToken();
    if (token != null) await send(userId, token);
  }

  /// Sends a token FCM just rotated, for [userId].
  Future<void> send(String userId, String token) async {
    if (await optOut.isOptedOut(userId)) return;
    try {
      await api.post(
        ApiPaths.meDevices,
        body: {'token': token, 'platform': platform},
      );
    } on Object {
      // The next sign-in tries again.
    }
  }

  /// Stops the reminders to this phone. Called on sign-out **before** the
  /// session is discarded — after, the request could not authenticate, and
  /// whoever signs in next on this phone would get the previous owner's
  /// reminders. The token is then retired at FCM too, so that a server that
  /// missed the request (no signal) forgets it on its next send.
  Future<void> forgetThisDevice() async {
    if (!device.isReady) return;
    final token = await device.currentToken();
    if (token == null) return;
    try {
      await api.delete(ApiPaths.meDevices, body: {'token': token});
    } on Object {
      // Retiring the token below covers this.
    }
    await device.deleteToken();
  }

  Future<bool> isEnabled(String userId) async =>
      !await optOut.isOptedOut(userId);

  /// Perfil's switch. Off forgets this phone the way signing out does — the
  /// token retired too, so that "off" holds even when the request found no
  /// signal; on registers it again, with the fresh token FCM hands out.
  Future<void> setEnabled(String userId, {required bool enabled}) async {
    await optOut.setOptedOut(userId, optedOut: !enabled);
    if (enabled) {
      await register(userId);
    } else {
      await forgetThisDevice();
    }
  }
}
