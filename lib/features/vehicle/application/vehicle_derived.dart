import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_profile_provider.dart';
import 'package:meu_auto/features/odometer/application/odometer_provider.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';

/// Refreshes everything the server derives from one vehicle's history.
///
/// A mileage, a service or a fill moves every distance-based due date, so the
/// dashboard, the plan list, an open plan detail and the profile all change
/// together — and so do the history and the costs that list the event. Each
/// write used to refresh its own subset, and the subsets disagreed: saving a
/// fill updated Início while Cuidados, kept alive by its tab, went on showing
/// the old distances until someone pulled to refresh.
///
/// One list, called after every write that touches the vehicle's history.
/// Invalidating a provider nobody is watching costs nothing — it refetches
/// only when a screen asks for it again — so there is no reason to be clever
/// about which subset a given write "really" needs.
void invalidateVehicleDerived(WidgetRef ref, String vehicleId) {
  invalidateVehicleDerivedWith(ref.invalidate, vehicleId);
}

/// The same list, for whoever holds a provider `Ref` rather than a
/// `WidgetRef` — the push coordinator, when a reminder is tapped: it exists
/// because something fell due, so what the tabs cached is already old.
void invalidateVehicleDerivedWith(
  void Function(ProviderOrFamily provider) invalidate,
  String vehicleId,
) {
  invalidate(dashboardProvider(vehicleId));
  invalidate(alertsProvider(vehicleId));
  invalidate(costsDashboardProvider);
  invalidate(maintenancePlansProvider(vehicleId));
  invalidate(maintenancePlansWithHiddenProvider(vehicleId));
  invalidate(maintenancePlanProvider);
  invalidate(maintenanceProfileProvider(vehicleId));
  invalidate(timelineProvider(vehicleId));
  invalidate(odometerHistoryProvider(vehicleId));
}
