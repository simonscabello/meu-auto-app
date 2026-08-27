import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_envelope.dart';

/// Every collection endpoint in the contract answers `{"data": [...]}`, and the
/// paginated ones add `"next_cursor"`. These helpers are the only place that
/// knows that, so they are also the only place that has to survive a response
/// arriving in a shape nobody expected.
void main() {
  group('listOf', () {
    test('parses each entry', () {
      final names = listOf({
        'data': [
          {'name': 'Argo'},
          {'name': 'Onix'},
        ],
      }, (json) => json['name'] as String);

      expect(names, ['Argo', 'Onix']);
    });

    test('an empty list is empty, not an error', () {
      expect(listOf({'data': <dynamic>[]}, (json) => json), isEmpty);
    });

    test('a missing data key yields an empty list', () {
      expect(listOf({}, (json) => json), isEmpty);
    });

    test('data arriving as something other than a list yields empty', () {
      expect(listOf({'data': 'nada disso'}, (json) => json), isEmpty);
    });

    test('a non-map entry is skipped, and the rest survive', () {
      final names = listOf({
        'data': [
          {'name': 'Argo'},
          'lixo',
          null,
          {'name': 'Onix'},
        ],
      }, (json) => json['name'] as String);

      // One bad row costs that row, never the screen.
      expect(names, ['Argo', 'Onix']);
    });
  });

  group('pageOf', () {
    test('carries the cursor through untouched', () {
      final page = pageOf({
        'data': [
          {'n': 1},
        ],
        'next_cursor': 'b3BhcXVl',
      }, (json) => json['n'] as int);

      expect(page.items, [1]);
      expect(page.nextCursor, 'b3BhcXVl');
    });

    test('a null cursor means the last page', () {
      final page = pageOf({
        'data': <dynamic>[],
        'next_cursor': null,
      }, (json) => json);

      expect(page.nextCursor, isNull);
      expect(page.items, isEmpty);
    });

    test('a missing cursor key also means the last page', () {
      expect(pageOf({'data': <dynamic>[]}, (json) => json).nextCursor, isNull);
    });
  });
}
