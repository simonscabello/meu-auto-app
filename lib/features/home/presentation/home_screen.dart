import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/presentation/dashboard_screen.dart';
import 'package:meu_auto/features/home/presentation/home_header.dart';
import 'package:meu_auto/features/update/presentation/app_update_notice.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_switcher_sheet.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';

/// The Início tab. No app bar: the header is part of the page, so the mark,
/// the account and the car scroll with the rest and the pull-to-refresh
/// starts from the very top.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedVehicleProvider);
    final vehicles = ref.watch(vehiclesProvider).valueOrNull?.vehicles ?? [];
    final vehicleId = selected.valueOrNull?.id;

    return AppScaffold(
      onRefresh: () => _refresh(ref, vehicleId),
      body: selected.when(
        loading: () => const DashboardSkeleton(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: AppErrorState.fromError(
            error: error,
            onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
          ),
        ),
        // A null vehicle cannot be reached from here: the router sends an
        // account with no vehicles to the first-vehicle form instead of the
        // shell. Rendering nothing is the safe answer if that ever changes.
        data: (vehicle) => vehicle == null
            ? const SizedBox.shrink()
            : DashboardView(
                vehicleId: vehicle.id,
                // The update notice rides in the header's slot so it shows in
                // every state, the failed one included — see AppUpdateNotice.
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppUpdateNotice(),
                    HomeHeader(
                      name: vehicle.headlineName,
                      metaParts: vehicle.brandAndYear,
                      plate: vehicle.plate,
                      canSwitch: vehicles.length > 1,
                      onSwitch: () => VehicleSwitcherSheet.show(context),
                      onAccount: () => context.push(AppRoutes.profile),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref, String? vehicleId) async {
    await ref.read(vehiclesProvider.notifier).reload();
    if (vehicleId == null) {
      return;
    }
    ref.invalidate(dashboardProvider(vehicleId));
    try {
      await ref.read(dashboardProvider(vehicleId).future);
    } on Object {
      // The provider already holds the failure and DashboardView renders it
      // with a retry. Rethrowing here would only crash the refresh indicator.
    }
  }
}
