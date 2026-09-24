import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// Which car the rest of the app is about.
///
/// Selection is a tick and an accent well; the name stays the colour every
/// other name in the app is. Material's `selected` tile painted the title and
/// the plate in the primary colour and the chosen car looked broken.
class VehicleSwitcherSheet extends ConsumerWidget {
  const VehicleSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => const VehicleSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(vehiclesProvider);
    final selected = ref.watch(selectedVehicleProvider).valueOrNull;

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
        data: (state) => VehicleSwitcherContent(
          vehicles: state.vehicles,
          selectedId: selected?.id,
          onSelect: (vehicle) async {
            await ref
                .read(selectedVehicleIdProvider.notifier)
                .select(vehicle.id);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          onAdd: () {
            Navigator.pop(context);
            context.push(AppRoutes.vehicleNew);
          },
        ),
      ),
    );
  }
}

/// The sheet as pure presentation, so the row can be tested without a
/// provider scope.
class VehicleSwitcherContent extends StatelessWidget {
  const VehicleSwitcherContent({
    super.key,
    required this.vehicles,
    this.selectedId,
    this.onSelect,
    this.onAdd,
  });

  final List<Vehicle> vehicles;
  final String? selectedId;
  final ValueChanged<Vehicle>? onSelect;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.s8,
          ),
          child: AppSheetHeader(title: 'Veículos', closable: false),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppGroup(
                  children: [
                    for (final vehicle in vehicles)
                      _VehicleRow(
                        key: ValueKey(vehicle.id),
                        vehicle: vehicle,
                        selected: vehicle.id == selectedId,
                        onTap: onSelect == null
                            ? null
                            : () => onSelect!(vehicle),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                AppGroup(
                  children: [
                    AppListRow(
                      icon: Icons.add,
                      iconTone: AppIconWellTone.accent,
                      title: 'Adicionar veículo',
                      onTap: onAdd,
                      showChevron: onAdd != null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One car: name, plate, and a tick when it is the one in use.
///
/// Built on [AppListRowShell] rather than [AppListRow] so the tick is inside
/// the tap target. A tick is not an action of its own — it is the state of
/// this row, and a dead spot on the right-hand edge of a row that is
/// otherwise tappable is the kind of thing people blame themselves for.
class _VehicleRow extends StatelessWidget {
  const _VehicleRow({
    super.key,
    required this.vehicle,
    required this.selected,
    this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plate = vehicle.plate?.trim();
    final name = vehicle.shortName;

    return AppListRowShell(
      onTap: onTap,
      semanticLabel: selected ? '$name, veículo em uso' : 'Usar $name',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconWell(
            icon: Icons.directions_car_outlined,
            tone: selected ? AppIconWellTone.accent : AppIconWellTone.neutral,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (plate != null && plate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    plate,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(width: AppSpacing.s8),
            Icon(Icons.check, size: 20, color: scheme.primary),
          ],
        ],
      ),
    );
  }
}
