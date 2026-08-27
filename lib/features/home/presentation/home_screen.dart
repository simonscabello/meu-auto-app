import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/presentation/dashboard_screen.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_switcher_sheet.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// The Início tab: the app bar identifies the car and switches between cars,
/// and the body is the dashboard for whichever one is selected.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedVehicleProvider);
    final vehicleId = selected.value?.id;

    return AppScaffold(
      titleWidget: selected.when(
        loading: () => const AppSkeleton(width: 180, height: 24),
        error: (error, _) => const Text('Início'),
        data: (vehicle) {
          if (vehicle == null) {
            return const Text('Início');
          }
          return _VehicleTitle(name: vehicle.displayName);
        },
      ),
      onRefresh: () => _refresh(ref, vehicleId),
      body: selected.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
        ),
        // A null vehicle cannot be reached from here: the router sends an
        // account with no vehicles to the first-vehicle form instead of the
        // shell. Rendering nothing is the safe answer if that ever changes.
        data: (vehicle) => vehicle == null
            ? const SizedBox.shrink()
            : DashboardView(vehicleId: vehicle.id),
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

class _VehicleTitle extends StatelessWidget {
  const _VehicleTitle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Trocar veículo. $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => VehicleSwitcherSheet.show(context),
        borderRadius: AppRadius.borderM,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Row(
            children: [
              Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}
