import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Placeholder "coming soon" copy. Due-soon phrases ("vence em breve") are
/// status language and stay.
void main() {
  test('lib has no coming-soon placeholder', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final placeholder = RegExp(
      r'entra(?:m)? em breve|chegando em breve',
      caseSensitive: false,
    );

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      expect(
        placeholder.hasMatch(source),
        isFalse,
        reason: '${file.path} still promises a feature "em breve"',
      );
    }
  });
}
