import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_switcher_sheet.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// The owner's cars, each opening its own detail.
///
/// The same row as the switcher — name, make and year, the plate as a plate,
/// a tick on the car in use — so the two lists read as one list. Adding a
/// car is the last row of it rather than a button in the bar.
class VehicleListScreen extends ConsumerWidget {
  const VehicleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(vehiclesProvider);
    final selectedId = ref.watch(selectedVehicleProvider).valueOrNull?.id;
    return AppScaffold(
      title: 'Meus veículos',
      onRefresh: () => ref.read(vehiclesProvider.notifier).reload(),
      body: list.when(
        loading: () => const Padding(
          padding: AppSpacing.screen,
          child: AppSkeletonList(count: 2),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
        ),
        data: (state) {
          if (state.vehicles.isEmpty) {
            return AppEmptyState(
              icon: Icons.directions_car_outlined,
              title: 'Nenhum veículo cadastrado',
              message:
                  'Cadastre o carro para acompanhar prazos, gastos e '
                  'histórico.',
              actionLabel: 'Cadastrar veículo',
              onAction: () => context.push(AppRoutes.vehicleNew),
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.screen,
            children: [
              AppGroup(
                children: [
                  for (final vehicle in state.vehicles)
                    VehicleChoiceRow(
                      key: ValueKey(vehicle.id),
                      vehicle: vehicle,
                      selected: vehicle.id == selectedId,
                      showChevron: true,
                      onTap: () => context.push(AppRoutes.vehicle(vehicle.id)),
                    ),
                  AppListRow(
                    icon: Icons.add,
                    iconTone: AppIconWellTone.accent,
                    title: 'Adicionar veículo',
                    onTap: () => context.push(AppRoutes.vehicleNew),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
