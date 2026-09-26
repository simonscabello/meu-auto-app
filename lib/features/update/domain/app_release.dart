/// A build the server says the app can update to.
///
/// Both values come from the server's app-version route
/// (`ApiPaths.appVersion`), where a person sets them once the GitHub Release
/// is up. The app never decides that a release exists; it
/// compares the number with its own and offers the download.
final class AppRelease {
  const AppRelease({required this.version, required this.apkUrl});

  /// `1.2.0` or `1.2.0+7` — the pubspec's format.
  final String version;

  /// Where the APK is downloaded from — `releases/latest/download` on GitHub,
  /// which follows the newest release on its own.
  final Uri apkUrl;

  /// The version as a person reads it: without the build number, which only
  /// the installer cares about.
  String get displayVersion => version.split('+').first;

  /// Null when nothing is announced, and also when what arrived cannot be
  /// acted on — a version this app cannot compare, a link that is not a web
  /// link. Either way the screen shows no notice: a bad value typed on the
  /// server must never turn into an error in the app.
  static AppRelease? fromJson(Map<String, dynamic> json) {
    final version = json['latest_version'];
    final link = json['apk_url'];
    if (version is! String || link is! String) return null;
    if (parseAppVersion(version) == null) return null;

    final url = Uri.tryParse(link.trim());
    if (url == null || !url.hasAuthority) return null;
    if (url.scheme != 'https' && url.scheme != 'http') return null;

    return AppRelease(version: version.trim(), apkUrl: url);
  }
}

final _versionPattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');

/// The four numbers of `1.2.0` or `1.2.0+7`, the build last; a version with
/// no build counts as build 0. Null for anything else.
List<int>? parseAppVersion(String raw) {
  final match = _versionPattern.firstMatch(raw.trim());
  if (match == null) return null;
  final parts = <int>[];
  for (var group = 1; group <= 4; group++) {
    final number = int.tryParse(match.group(group) ?? '0');
    if (number == null) return null;
    parts.add(number);
  }
  return parts;
}

/// Whether [candidate] is a later build than [installed], number by number.
///
/// `1.2.0` announced to a phone on `1.2.0+7` is not newer: the server may say
/// the version without the build, and that must not ask anyone to reinstall
/// what they already have. False whenever either side cannot be read — the
/// notice is an invitation, and a malformed number invites nobody.
bool isNewerVersion(String candidate, String installed) {
  final next = parseAppVersion(candidate);
  final current = parseAppVersion(installed);
  if (next == null || current == null) return false;
  for (var i = 0; i < next.length; i++) {
    if (next[i] != current[i]) return next[i] > current[i];
  }
  return false;
}
