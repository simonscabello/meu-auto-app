import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

class VehicleSwitcherSheet extends ConsumerWidget {
  const VehicleSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => const VehicleSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(vehiclesProvider);
    final selected = ref.watch(selectedVehicleProvider).value;
    return SafeArea(
      child: list.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.s24),
          child: AppSkeletonList(),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: AppErrorState.fromError(
            error: error,
            onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
          ),
        ),
        data: (state) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  0,
                  AppSpacing.s16,
                  AppSpacing.s8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Veículos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final vehicle in state.vehicles)
                      ListTile(
                        title: Text(vehicle.displayName),
                        subtitle: vehicle.plate == null
                            ? null
                            : Text(vehicle.plate!),
                        selected: selected?.id == vehicle.id,
                        trailing: selected?.id == vehicle.id
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () async {
                          await ref
                              .read(selectedVehicleIdProvider.notifier)
                              .select(vehicle.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Adicionar veículo'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.vehicleNew);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
