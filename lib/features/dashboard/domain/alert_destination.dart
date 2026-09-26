import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';

/// Where something the server calls an alert reference opens: the alerts
/// list, and the push reminder that names the same item — one map, so the
/// lock screen and the list lead to the same screen.
///
/// An unknown kind lands on the maintenance tab rather than inventing a
/// screen.
String routeForReference(AlertReferenceType type, String referenceId) {
  return switch (type) {
    AlertReferenceType.maintenanceRecord => AppRoutes.maintenanceRecord(
      referenceId,
    ),
    AlertReferenceType.maintenancePlan => AppRoutes.plan(referenceId),
    AlertReferenceType.obligation => AppRoutes.obligation(referenceId),
    AlertReferenceType.seguro => AppRoutes.seguro(referenceId),
    AlertReferenceType.desconhecido => AppRoutes.care,
  };
}
