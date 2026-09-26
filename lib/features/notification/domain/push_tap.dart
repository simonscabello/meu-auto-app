import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/features/dashboard/domain/alert_destination.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';

/// What a tapped reminder asks the app to open: which car, and — when the
/// reminder named a single item — which item.
///
/// The server sends the item in the alerts' own terms (`reference_type`,
/// `reference_id`), not a route: where an alert opens is the app's decision,
/// already made once for the alerts list ([routeForReference]).
final class PushTap {
  const PushTap({
    required this.vehicleId,
    this.referenceType,
    this.referenceId,
  });

  final String vehicleId;
  final AlertReferenceType? referenceType;
  final String? referenceId;

  /// Null for anything that is not a reminder this build understands: an
  /// unknown `kind` from a newer server opens nothing rather than the wrong
  /// thing.
  static PushTap? fromData(Map<String, String> data) {
    if (data['kind'] != 'reminder') return null;
    final vehicleId = data['vehicle_id'];
    if (vehicleId == null || vehicleId.isEmpty) return null;

    final referenceId = data['reference_id'];
    final referenceType = data['reference_type'];
    if (referenceId == null || referenceId.isEmpty || referenceType == null) {
      return PushTap(vehicleId: vehicleId);
    }
    return PushTap(
      vehicleId: vehicleId,
      referenceType: AlertReferenceType.fromWire(referenceType),
      referenceId: referenceId,
    );
  }

  /// One item opens that item; several open the car's list of alerts.
  String get route {
    final type = referenceType;
    final id = referenceId;
    if (type == null || id == null || type == AlertReferenceType.desconhecido) {
      return AppRoutes.alerts;
    }
    return routeForReference(type, id);
  }
}
