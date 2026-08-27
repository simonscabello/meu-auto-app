import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/config/app_config.dart';
import 'package:meu_auto/core/network/api_paths.dart';

void main() {
  test('parameterised paths interpolate the id', () {
    expect(ApiPaths.vehicleDashboard('abc'), '/vehicles/abc/dashboard');
    expect(ApiPaths.vehicle('abc'), '/vehicles/abc');
    expect(ApiPaths.odometer('r1'), '/odometer/r1');
  });

  test('v1-relative paths do not repeat the /v1 prefix', () {
    expect(ApiPaths.authLogin, '/auth/login');
    expect(ApiPaths.vehicles, '/vehicles');
    expect(ApiPaths.me, '/me');
  });

  test('health probes live on the origin, not under /v1', () {
    expect(ApiPaths.healthz, '${AppConfig.apiBaseUrl}/healthz');
    expect(ApiPaths.readyz, '${AppConfig.apiBaseUrl}/readyz');
  });

  test('no API path literal exists outside api_paths.dart', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final pathPattern = RegExp(
      "['\"]/(auth|vehicles|me|odometer|maintenance-|obligations|seguros)",
    );

    for (final file in dartFiles) {
      final normalised = file.path.replaceAll('\\', '/');
      if (normalised.endsWith('lib/core/network/api_paths.dart') ||
          normalised.endsWith('lib/core/router/app_routes.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      expect(
        source.contains('/v1/'),
        isFalse,
        reason: '$normalised contains a /v1/ path',
      );
      expect(
        pathPattern.hasMatch(source),
        isFalse,
        reason: '$normalised contains an API path literal',
      );
    }
  });
}
