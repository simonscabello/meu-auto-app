import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/timeline/domain/timeline_entry.dart';

final class TimelineRepository {
  TimelineRepository({required this.api});

  final ApiClient api;

  Future<CursorPage<TimelineEntry>> list(
    String vehicleId, {
    int? limit,
    String? cursor,
  }) async {
    final body = await api.get(
      ApiPaths.vehicleTimeline(vehicleId),
      query: api.paginationQuery(limit: limit, cursor: cursor),
    );
    return pageOf(body, TimelineEntry.fromJson);
  }
}
