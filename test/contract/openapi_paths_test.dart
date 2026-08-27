import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Compensates for not generating the Dart client from OpenAPI: a path the
/// app calls must still exist on the contract. Extra server routes are fine.
void main() {
  test('every ApiPaths route exists in the OpenAPI contract', () {
    final specFile = File('../meu-auto-backend/api/openapi.yaml');
    if (!specFile.existsSync()) {
      markTestSkipped(
        'Repositório irmão ausente: ${specFile.path} não existe. '
        'O clone de meu-auto-backend não é obrigatório para rodar o app.',
      );
      return;
    }

    final spec = loadYaml(specFile.readAsStringSync());
    if (spec is! YamlMap) {
      fail('openapi.yaml is not a mapping');
    }
    final pathsNode = spec['paths'];
    if (pathsNode is! YamlMap) {
      fail('openapi.yaml has no paths');
    }
    final contract = {
      for (final key in pathsNode.keys) _normalize(key.toString()),
    };

    final source = File('lib/core/network/api_paths.dart').readAsStringSync();
    final used = _appPathTemplates(source);
    expect(used, isNotEmpty, reason: 'api_paths.dart had no extractable paths');

    final missing = [
      for (final path in used)
        if (!contract.contains(path)) path,
    ]..sort();

    expect(
      missing,
      isEmpty,
      reason:
          'ApiPaths references routes that are not in openapi.yaml:\n'
          '  ${missing.join('\n  ')}',
    );
  });
}

Set<String> _appPathTemplates(String source) {
  final paths = <String>{};
  for (final match in RegExp(
    r"(?:const \w+ =|=>)\s*'(/[^']+)'",
  ).allMatches(source)) {
    paths.add(_normalize('/v1${match.group(1)!}'));
  }
  if (source.contains('/healthz')) {
    paths.add('/healthz');
  }
  if (source.contains('/readyz')) {
    paths.add('/readyz');
  }
  return paths;
}

String _normalize(String path) {
  return path
      .replaceAll(r'$id', '{id}')
      .replaceAll(RegExp(r'\{[^}]+\}'), '{id}');
}
