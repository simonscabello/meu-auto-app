import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';

/// A cursor-paginated list scoped to one argument — in practice, a vehicle id.
///
/// Extracted at the second occurrence, not the first: the odometer history and
/// the maintenance history had the same cursor bookkeeping, and four more
/// paginated lists are coming. A subclass writes [fetchPage] and nothing else.
///
/// The cursor is deliberately private and never leaves this class. The contract
/// says it is opaque and may change shape, so nothing above the data layer is
/// allowed to look at it.
abstract class PagedFamilyController<T, Arg>
    extends FamilyAsyncNotifier<PagedState<T>, Arg> {
  static const defaultPageSize = 30;

  String? _cursor;

  int get pageSize => defaultPageSize;

  /// Fetches one page. [cursor] is null for the first.
  Future<CursorPage<T>> fetchPage({
    required Arg arg,
    required int limit,
    String? cursor,
  });

  @override
  Future<PagedState<T>> build(Arg arg) async {
    final page = await fetchPage(arg: arg, limit: pageSize);
    _cursor = page.nextCursor;
    return PagedState(items: page.items, hasMore: page.nextCursor != null);
  }

  /// Appends the next page.
  ///
  /// A failure here keeps everything already on screen and surfaces as a footer
  /// the reader can retry: losing a loaded list because page four failed would
  /// be worse than the failure itself.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        _cursor == null) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await fetchPage(arg: arg, limit: pageSize, cursor: _cursor);
      _cursor = page.nextCursor;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          isLoadingMore: false,
          hasMore: page.nextCursor != null,
        ),
      );
    } on Object catch (error) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, lastPageError: error),
      );
    }
  }

  /// Drops entries from the loaded list after the server accepted their
  /// removal. Local only — it issues no request and refreshes nothing that
  /// derives from the list.
  void removeWhere(bool Function(T item) test) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final item in current.items)
            if (!test(item)) item,
        ],
      ),
    );
  }
}
