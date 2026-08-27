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
