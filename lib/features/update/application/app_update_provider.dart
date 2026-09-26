import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/config/app_config.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/features/update/data/app_release_repository.dart';
import 'package:meu_auto/features/update/domain/app_release.dart';

final appReleaseRepositoryProvider = Provider<AppReleaseRepository>((ref) {
  return AppReleaseRepository(api: ref.watch(apiClientProvider));
});

/// The version this build carries, or null where an APK does not apply.
///
/// Null on iOS, which updates through the App Store; on the web, which has no
/// APK; and in any build the release workflow did not make, which has no
/// `APP_VERSION` and so is never told to replace itself with the published
/// one. A provider rather than a getter so a test can say which build it is.
final installedAppVersionProvider = Provider<String?>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  return AppConfig.appVersion.isEmpty ? null : AppConfig.appVersion;
});

/// How long coming back to the app waits before asking again.
const appUpdateRecheckAfter = Duration(minutes: 15);

/// The published release this build can update to, or null.
///
/// Asked when Início first draws, and again when the app returns to the
/// foreground after [appUpdateRecheckAfter]: Android keeps a process alive
/// for days, so asking once per launch left a phone that never closes the app
/// without ever hearing of the new version. The pause is there because coming
/// back from the date picker or the photo gallery is also "coming back".
///
/// Every failure is silence. The notice is an invitation, and not being able
/// to ask for it must never become an error on Início.
final appUpdateProvider = FutureProvider<AppRelease?>((ref) async {
  final installed = ref.watch(installedAppVersionProvider);
  if (installed == null) return null;

  // Elapsed time, so a stopwatch: every DateTime.now() in lib/features is a
  // date-picker bound, and this is not one.
  final sinceAsked = Stopwatch()..start();
  final listener = AppLifecycleListener(
    onResume: () {
      if (sinceAsked.elapsed >= appUpdateRecheckAfter) ref.invalidateSelf();
    },
  );
  ref.onDispose(listener.dispose);

  try {
    final release = await ref.watch(appReleaseRepositoryProvider).latest();
    if (release == null || !isNewerVersion(release.version, installed)) {
      return null;
    }
    return release;
  } on ApiFailure {
    return null;
  }
});
