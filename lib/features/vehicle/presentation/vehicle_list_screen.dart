import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
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
            padding: const EdgeInsets.all(AppSpacing.s16),
            itemCount: state.vehicles.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.s12),
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
    final theme = Theme.of(context);
    final nick = vehicle.nickname?.trim();
    final hasNick = nick != null && nick.isNotEmpty;
    return AppCard(
      onTap: () => context.push(AppRoutes.vehicle(vehicle.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(vehicle.displayName, style: theme.textTheme.titleMedium),
          if (hasNick) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              '${vehicle.brand} ${vehicle.model}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (vehicle.plate != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(vehicle.plate!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.s4),
          Text(
            formatKm(vehicle.currentMileageKm),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
