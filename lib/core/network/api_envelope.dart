import 'package:meu_auto/core/domain/cursor_page.dart';

/// Unwraps the two list shapes the API uses.
///
/// Every collection endpoint answers `{"data": [...]}`, and the paginated ones
/// add `"next_cursor"`. Two repositories had already written this loop by hand
/// in slightly different ways, and six more endpoints are coming — so it lives
/// in one place before the sixth copy exists.
///
/// Malformed entries are skipped rather than fatal: one bad row in a page of
/// thirty should cost that row, not the screen.
List<T> listOf<T>(
  Map<String, dynamic> body,
  T Function(Map<String, dynamic> json) parse,
) {
  final data = body['data'];
  if (data is! List) return const [];
  return [
    for (final item in data)
      if (item is Map) parse(Map<String, dynamic>.from(item)),
  ];
}

/// One page of a cursor-paginated list.
///
/// `next_cursor` is opaque and is passed back untouched — the format is the
/// server's business and the contract says so explicitly.
CursorPage<T> pageOf<T>(
  Map<String, dynamic> body,
  T Function(Map<String, dynamic> json) parse,
) {
  return CursorPage(
    items: listOf(body, parse),
    nextCursor: body['next_cursor'] as String?,
  );
}
