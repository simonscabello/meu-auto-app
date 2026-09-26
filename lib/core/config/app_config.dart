/// Compile-time configuration. Values come from `--dart-define-from-file`.
///
/// [apiBaseUrl] defaults to `http://10.0.2.2:8080` because the Android
/// emulator maps that address to the host machine's loopback. `localhost`
/// inside the emulator is the emulator itself, not the Windows host where
/// the API runs.
final class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String apiUrl = '$apiBaseUrl/v1';

  /// The version this build was published as — the pubspec's `version:`,
  /// `1.2.0+7` — handed in by the release workflow
  /// (`.github/workflows/release-apk.yml`), which reads it from the pubspec.
  ///
  /// Empty in every other build, and that is deliberate: a build made on the
  /// development machine is never told to replace itself with the published
  /// one. It is a define rather than a plugin that reads the package because
  /// the only build that needs to know its version is the one the workflow
  /// makes, and the workflow already knows it.
  static const String appVersion = String.fromEnvironment('APP_VERSION');

  /// False for emulator loopback, host loopback, and LAN IPs used when a
  /// physical device talks to the machine running the API.
  static bool get isProduction {
    final host = Uri.parse(apiBaseUrl).host;
    if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return false;
    }
    return !_isPrivateIpv4(host);
  }

  static const Duration connectTimeout = Duration(seconds: 10);

  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Sending a photo. Below the server's 30-second write window, so a slow
  /// upload fails here with a message rather than as a dropped connection.
  static const Duration uploadTimeout = Duration(seconds: 25);

  static bool _isPrivateIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) {
      return false;
    }
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    if (first == null || second == null) {
      return false;
    }
    if (first == 10) {
      return true;
    }
    if (first == 192 && second == 168) {
      return true;
    }
    return first == 172 && second >= 16 && second <= 31;
  }
}
