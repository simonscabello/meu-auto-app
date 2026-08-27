import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';

void main() {
  test('CursorPage keeps items and a nullable next cursor', () {
    const page = CursorPage<int>(items: [1, 2], nextCursor: 'abc');
    expect(page.items, [1, 2]);
    expect(page.nextCursor, 'abc');

    const last = CursorPage<int>(items: [3]);
    expect(last.nextCursor, isNull);
  });

  test('PagedState holds accumulated items and the last-page error', () {
    const state = PagedState<String>(
      items: ['a'],
      isLoadingMore: true,
      hasMore: true,
      lastPageError: 'falhou',
    );
    expect(state.items, ['a']);
    expect(state.isLoadingMore, isTrue);
    expect(state.hasMore, isTrue);
    expect(state.lastPageError, 'falhou');
  });
}
