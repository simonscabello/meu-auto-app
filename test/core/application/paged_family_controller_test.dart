import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/application/paged_family_controller.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';

/// Two features page through lists with this now, and four more will. The
/// behaviour that matters is what happens when a page fails: everything already
/// on screen has to survive it.
void main() {
  late ProviderContainer container;
  late _FakeSource source;

  setUp(() {
    source = _FakeSource();
    container = ProviderContainer(
      overrides: [_sourceProvider.overrideWithValue(source)],
    );
    addTearDown(container.dispose);
  });

  Future<PagedState<int>> read() => container.read(_pagedProvider('v1').future);

  test('the first page is loaded on build', () async {
    source.pages = [
      const CursorPage(items: [1, 2, 3], nextCursor: 'c1'),
    ];

    final state = await read();

    expect(state.items, [1, 2, 3]);
    expect(state.hasMore, isTrue);
    expect(source.requestedCursors, [null]);
  });

  test('loadMore appends and follows the cursor', () async {
    source.pages = [
      const CursorPage(items: [1, 2], nextCursor: 'c1'),
      const CursorPage(items: [3, 4], nextCursor: 'c2'),
    ];

    await read();
    await container.read(_pagedProvider('v1').notifier).loadMore();

    final state = container.read(_pagedProvider('v1')).value!;
    expect(state.items, [1, 2, 3, 4]);
    expect(source.requestedCursors, [null, 'c1']);
  });

  test('a null cursor is the last page, and loadMore stops asking', () async {
    source.pages = [
      const CursorPage(items: [1, 2]),
    ];

    final state = await read();
    expect(state.hasMore, isFalse);

    await container.read(_pagedProvider('v1').notifier).loadMore();
    await container.read(_pagedProvider('v1').notifier).loadMore();

    // Still one request: there is nothing left to fetch.
    expect(source.requestedCursors, [null]);
  });

  test('a failed page keeps what is already loaded', () async {
    source.pages = [
      const CursorPage(items: [1, 2], nextCursor: 'c1'),
    ];

    await read();
    // The first page is in; it is the SECOND that fails.
    source.failNext = true;
    await container.read(_pagedProvider('v1').notifier).loadMore();

    final state = container.read(_pagedProvider('v1')).value!;
    expect(state.items, [1, 2], reason: 'nothing was thrown away');
    expect(state.isLoadingMore, isFalse);
    expect(state.lastPageError, isA<StateError>());
    expect(state.hasMore, isTrue, reason: 'still retryable');
  });

  test('retrying after a failure clears the error and appends', () async {
    source.pages = [
      const CursorPage(items: [1, 2], nextCursor: 'c1'),
      const CursorPage(items: [3], nextCursor: null),
    ];

    await read();
    source.failNext = true;
    await container.read(_pagedProvider('v1').notifier).loadMore();
    await container.read(_pagedProvider('v1').notifier).loadMore();

    final state = container.read(_pagedProvider('v1')).value!;
    expect(state.items, [1, 2, 3]);
    expect(state.lastPageError, isNull);
    expect(state.hasMore, isFalse);
  });

  test('removeWhere drops entries locally without a request', () async {
    source.pages = [
      const CursorPage(items: [1, 2, 3]),
    ];

    await read();
    container.read(_pagedProvider('v1').notifier).removeWhere((n) => n == 2);

    expect(container.read(_pagedProvider('v1')).value!.items, [1, 3]);
    expect(source.requestedCursors, hasLength(1));
  });

  test('each argument keeps its own list and its own cursor', () async {
    source.pages = [
      const CursorPage(items: [1], nextCursor: 'c1'),
      const CursorPage(items: [9], nextCursor: null),
    ];

    expect((await container.read(_pagedProvider('v1').future)).items, [1]);
    expect((await container.read(_pagedProvider('v2').future)).items, [9]);
  });
}

final _sourceProvider = Provider<_FakeSource>((ref) => _FakeSource());

final _pagedProvider =
    AsyncNotifierProvider.family<_FakeController, PagedState<int>, String>(
      _FakeController.new,
    );

class _FakeController extends PagedFamilyController<int, String> {
  @override
  Future<CursorPage<int>> fetchPage({
    required String arg,
    required int limit,
    String? cursor,
  }) {
    return ref.read(_sourceProvider).fetch(cursor);
  }
}

final class _FakeSource {
  List<CursorPage<int>> pages = const [];
  final List<String?> requestedCursors = [];
  bool failNext = false;
  int _served = 0;

  Future<CursorPage<int>> fetch(String? cursor) async {
    if (failNext) {
      failNext = false;
      throw StateError('página indisponível');
    }
    requestedCursors.add(cursor);
    final page = pages[_served];
    _served++;
    return page;
  }
}
