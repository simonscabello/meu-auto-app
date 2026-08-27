import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no file in lib/core/domain imports Flutter', () {
    final dir = Directory('lib/core/domain');
    expect(dir.existsSync(), isTrue);
    final dartFiles = dir.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.dart'),
    );
    expect(dartFiles, isNotEmpty);
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      expect(
        source.contains('package:flutter'),
        isFalse,
        reason: '${file.path} imports Flutter',
      );
    }
  });
}
