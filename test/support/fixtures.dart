import 'dart:convert';
import 'dart:io';

/// Loads a JSON object from `test/fixtures/`.
///
/// Shapes were taken from `../meu-auto-backend/test/golden/*.json` (keys and
/// nullability). Values are realistic so `fromJson` can actually run.
Map<String, dynamic> loadFixture(String name) {
  final file = File('test/fixtures/$name');
  if (!file.existsSync()) {
    throw StateError(
      'Fixture test/fixtures/$name not found (cwd: ${Directory.current.path})',
    );
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    throw StateError('Fixture $name is not a JSON object');
  }
  return Map<String, dynamic>.from(decoded);
}

Map<String, dynamic> withoutKey(Map<String, dynamic> json, String key) {
  return Map<String, dynamic>.from(json)..remove(key);
}

Map<String, dynamic> asMap(Object? value) {
  return Map<String, dynamic>.from(value as Map);
}

List<Map<String, dynamic>> asObjectList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}
