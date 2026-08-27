import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';

/// Same `/dashboard` read model as Início, with a chosen `cost_months`.
///
/// There is no costs endpoint. The period selector only changes the query
/// parameter; the rest of the payload is ignored here.
final costsDashboardProvider =
    FutureProvider.family<Dashboard, ({String vehicleId, int months})>((
      ref,
      query,
    ) {
      return ref
          .watch(dashboardRepositoryProvider)
          .get(query.vehicleId, costMonths: query.months);
    });
