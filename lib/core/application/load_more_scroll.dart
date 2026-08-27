import 'package:flutter/widgets.dart';

/// How close to the bottom a list gets before the next page is asked for.
///
/// Far enough that the page usually arrives before the owner reaches the end,
/// close enough that idly scrolling one screen does not fetch the whole
/// history.
const _prefetchExtent = 400.0;

/// Whether [controller] has scrolled near enough to the bottom to load more.
///
/// The three paginated screens — odometer history, maintenance history and the
/// timeline — had the same listener down to the constant. What differs between
/// them is only which [PagedFamilyController] gets `loadMore()`, so that stays
/// at the call site and the threshold lives here.
///
/// Returns false while the controller has no clients: during the first build,
/// and after a dispose, there is no position to measure.
bool shouldLoadMore(ScrollController controller) {
  if (!controller.hasClients) {
    return false;
  }
  final position = controller.position;
  return position.maxScrollExtent - position.pixels < _prefetchExtent;
}
