import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_plate_chip.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// Which car the rest of the app is about.
///
/// Selection is a tick; the name stays the colour every other name in the
/// app is. Material's `selected` tile painted the title and the plate in the
/// primary colour and the chosen car looked broken.
///
/// With one car the sheet still opens: it shows that car, and it is where the
/// second one is added and where the car's own details are.
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

    void leaveTo(String location) {
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push(location);
    }

    return list.when(
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.s24,
        ),
        child: AppSkeletonList(count: 2),
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
          await ref.read(selectedVehicleIdProvider.notifier).select(vehicle.id);
          if (context.mounted) {
            Navigator.pop(context);
          }
        },
        onAdd: () => leaveTo(AppRoutes.vehicleNew),
        onOpenDetail: (vehicle) => leaveTo(AppRoutes.vehicle(vehicle.id)),
      ),
    );
  }
}

/// The sheet as pure presentation, so the rows can be tested without a
/// provider scope.
class VehicleSwitcherContent extends StatelessWidget {
  const VehicleSwitcherContent({
    super.key,
    required this.vehicles,
    this.selectedId,
    this.onSelect,
    this.onAdd,
    this.onOpenDetail,
  });

  final List<Vehicle> vehicles;
  final String? selectedId;
  final ValueChanged<Vehicle>? onSelect;
  final VoidCallback? onAdd;

  /// Opens the car in use — its plate, documents and the rest of its record.
  final ValueChanged<Vehicle>? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    Vehicle? inUse;
    for (final vehicle in vehicles) {
      if (vehicle.id == selectedId) inUse = vehicle;
    }
    final detail = inUse;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.s12,
          ),
          child: AppSheetHeader(title: 'Seus veículos', closable: false),
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
                      VehicleChoiceRow(
                        key: ValueKey(vehicle.id),
                        vehicle: vehicle,
                        selected: vehicle.id == selectedId,
                        onTap: onSelect == null
                            ? null
                            : () => onSelect!(vehicle),
                      ),
                    // The way to add one is the last row of the list: "and
                    // one more here".
                    if (onAdd != null)
                      AppListRow(
                        icon: Icons.add,
                        iconTone: AppIconWellTone.accent,
                        title: 'Adicionar veículo',
                        onTap: onAdd,
                      ),
                  ],
                ),
                if (detail != null && onOpenDetail != null) ...[
                  const SizedBox(height: AppSpacing.s16),
                  AppGroup(
                    children: [
                      AppListRow(
                        icon: Icons.info_outlined,
                        title: 'Detalhes do veículo',
                        subtitle: detail.shortName,
                        showChevron: true,
                        onTap: () => onOpenDetail!(detail),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One of the owner's cars: the name, the make and year under it, the plate
/// drawn as a plate, and a tick when it is the one in use.
///
/// Built on [AppListRowShell] rather than [AppListRow] so the tick is inside
/// the tap target. A tick is not an action of its own — it is the state of
/// this row, and a dead spot on the right-hand edge of a row that is
/// otherwise tappable is the kind of thing people blame themselves for.
class VehicleChoiceRow extends StatelessWidget with GroupedRow {
  const VehicleChoiceRow({
    super.key,
    required this.vehicle,
    required this.selected,
    this.onTap,
    this.showChevron = false,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback? onTap;

  /// For a row that opens the car rather than choosing it.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plate = vehicle.plate?.trim();
    final hasPlate = plate != null && plate.isNotEmpty;
    final name = vehicle.headlineName;
    final meta = vehicle.brandAndYear.join(dotSep);
    final spoken = [
      name,
      if (meta.isNotEmpty) meta,
      if (hasPlate) 'placa $plate',
      if (selected) 'veículo em uso',
    ].join('. ');

    return AppListRowShell(
      onTap: onTap,
      semanticLabel: spoken,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppIconWell(icon: Icons.directions_car_outlined),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: theme.textTheme.titleSmall),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (hasPlate) ...[
            const SizedBox(width: AppSpacing.s12),
            AppPlateChip(plate: plate),
          ],
          // The same slot on every row, ticked or not, so the plates line up.
          const SizedBox(width: AppSpacing.s8),
          SizedBox(
            width: 20,
            child: selected
                ? Icon(Icons.check, size: 20, color: scheme.primary)
                : null,
          ),
          if (showChevron) ...[
            const SizedBox(width: AppSpacing.s4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ],
        ],
      ),
    );
  }
}
