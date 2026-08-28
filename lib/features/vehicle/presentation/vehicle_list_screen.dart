import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

class VehicleListScreen extends ConsumerWidget {
  const VehicleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(vehiclesProvider);
    return AppScaffold(
      title: 'Meus veículos',
      actions: [
        AppIconButton(
          label: 'Adicionar veículo',
          icon: Icons.add,
          onPressed: () => context.push(AppRoutes.vehicleNew),
        ),
      ],
      onRefresh: () => ref.read(vehiclesProvider.notifier).reload(),
      body: list.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.s24),
          child: AppSkeletonList(),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
        ),
        data: (state) {
          if (state.vehicles.isEmpty) {
            return AppEmptyState(
              title: 'Cadastre seu primeiro veículo',
              message:
                  'Com o carro cadastrado, os prazos e o histórico ficam neste app.',
              actionLabel: 'Cadastrar',
              onAction: () => context.push(AppRoutes.vehicleNew),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              AppSpacing.s32,
            ),
            itemCount: state.vehicles.length,
            separatorBuilder: (context, index) => const AppRowDivider(),
            itemBuilder: (context, index) {
              return _VehicleTile(vehicle: state.vehicles[index]);
            },
          );
        },
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      icon: Icons.directions_car_outlined,
      title: vehicle.displayName,
      subtitle: _detail(),
      onTap: () => context.push(AppRoutes.vehicle(vehicle.id)),
      showChevron: true,
    );
  }

  /// What tells two of the owner's cars apart, in one line.
  ///
  /// The nickname is already the title when there is one, so the make and
  /// model only appear underneath in that case — repeating "Fiat Argo" as
  /// both title and subtitle is how the old card ended up four lines tall
  /// for a vehicle with three facts.
  String _detail() {
    final nick = vehicle.nickname?.trim();
    final parts = <String>[
      if (nick != null && nick.isNotEmpty) '${vehicle.brand} ${vehicle.model}',
      ?vehicle.plate,
      formatKm(vehicle.currentMileageKm),
    ];
    return parts.join(' · ');
  }
}
