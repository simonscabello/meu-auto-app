/// One page of a cursor-paginated list. [nextCursor] is null on the last page.
/// Pass it back to the API as-is; do not interpret it.
final class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

/// Accumulated items of a paged list in memory. No networking lives here.
final class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastPageError,
  });

  final List<T> items;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? lastPageError;

  /// [lastPageError] is cleared unless explicitly passed, because every state
  /// change that is not itself a failure has resolved the previous one.
  PagedState<T> copyWith({
    List<T>? items,
    bool? isLoadingMore,
    bool? hasMore,
    Object? lastPageError,
  }) {
    return PagedState<T>(
      items: items ?? this.items,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastPageError: lastPageError,
    );
  }
}
