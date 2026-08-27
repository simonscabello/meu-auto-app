import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/application/paged_family_controller.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/features/timeline/data/timeline_repository.dart';
import 'package:meu_auto/features/timeline/domain/timeline_entry.dart';

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  return TimelineRepository(api: ref.watch(apiClientProvider));
});

/// The unified history of one vehicle, newest first, one cursor page at a time.
final timelineProvider =
    AsyncNotifierProvider.family<
      TimelineController,
      PagedState<TimelineEntry>,
      String
    >(TimelineController.new);

class TimelineController extends PagedFamilyController<TimelineEntry, String> {
  @override
  Future<CursorPage<TimelineEntry>> fetchPage({
    required String arg,
    required int limit,
    String? cursor,
  }) {
    return ref
        .read(timelineRepositoryProvider)
        .list(arg, limit: limit, cursor: cursor);
  }
}
