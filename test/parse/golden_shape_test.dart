import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

/// When the sibling backend repo is checked out, fixtures must carry the same
/// keys the golden files describe. Values differ (goldens store types, we
/// store parseable examples); a renamed or vanished field is the bug.
void main() {
  final goldensDir = Directory('../meu-auto-backend/test/golden');

  test('fixtures keep the keys of the backend golden shapes', () {
    if (!goldensDir.existsSync()) {
      markTestSkipped(
        'Repositório irmão ausente: ${goldensDir.path} não existe. '
        'O clone de meu-auto-backend não é obrigatório para rodar o app.',
      );
      return;
    }

    const pairs = <(String, String)>[
      ('auth_login.json', 'auth_login.json'),
      ('me_get.json', 'me_get.json'),
      ('vehicle_get.json', 'vehicle_get.json'),
      ('vehicles_list.json', 'vehicles_list.json'),
      ('dashboard.json', 'dashboard.json'),
      ('alerts.json', 'alerts.json'),
      ('odometer_create.json', 'odometer_create.json'),
      ('odometer_list.json', 'odometer_list.json'),
      ('maintenance_items_list.json', 'maintenance_items_list.json'),
      ('maintenance_plans_list.json', 'maintenance_plans_list.json'),
      ('maintenance_record_get.json', 'maintenance_record_get.json'),
      ('timeline.json', 'timeline.json'),
      ('error_validation.json', 'error_validation.json'),
      ('error_odometer_rollback.json', 'error_odometer_rollback.json'),
      ('error_unauthorized.json', 'error_unauthorized.json'),
      ('error_not_found.json', 'error_not_found.json'),
      ('error_upstream_unavailable.json', 'error_upstream_unavailable.json'),
    ];

    for (final (goldenName, fixtureName) in pairs) {
      final goldenFile = File('${goldensDir.path}/$goldenName');
      expect(goldenFile.existsSync(), isTrue, reason: goldenName);
      final golden = jsonDecode(goldenFile.readAsStringSync());
      expect(golden, isA<Map>(), reason: goldenName);
      final shape = (golden as Map)['body'];
      expect(shape, isNotNull, reason: '$goldenName has no body');
      expectSameKeys(shape, loadFixture(fixtureName), fixtureName);
    }
  });
}

void expectSameKeys(Object? golden, Object? fixture, String path) {
  if (golden is Map && fixture is Map) {
    expect(
      fixture.keys.map((key) => key.toString()).toSet(),
      golden.keys.map((key) => key.toString()).toSet(),
      reason: path,
    );
    for (final key in golden.keys) {
      expectSameKeys(golden[key], fixture[key.toString()], '$path.$key');
    }
    return;
  }
  if (golden is List && fixture is List) {
    if (golden.isEmpty || fixture.isEmpty) {
      return;
    }
    expectSameKeys(golden.first, fixture.first, '$path[0]');
  }
}
