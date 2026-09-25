import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_form_sheet.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/presentation/obligation_form_sheet.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';

/// What kind of record to add, asked from the one screen where the question
/// makes sense.
///
/// Histórico is where a choice among record types is the right question,
/// because the history is exactly the place all of them land. Every other
/// screen offers its own single action in its own words.
///
/// "Adicionar veículo" is deliberately not here. A vehicle is not an event in
/// a vehicle's history; it lives in the vehicle switcher and in Perfil.
class AddRecordSheet extends ConsumerWidget {
  const AddRecordSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => const AddRecordSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(selectedVehicleProvider).valueOrNull;
    if (vehicle == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetHeader(title: 'Adicionar registro', closable: false),
          const SizedBox(height: AppSpacing.s8),
          AppGroup(
            children: [
              // Ordered by how often a person actually does each one, not
              // by how the data model is organised.
              if (vehicle.refueling.supported)
                AppListRow(
                  icon: Icons.local_gas_station_outlined,
                  title: 'Registrar abastecimento',
                  showChevron: true,
                  onTap: () {
                    Navigator.pop(context);
                    final lastFuel = ref
                        .read(dashboardProvider(vehicle.id))
                        .valueOrNull
                        ?.lastAbastecimento
                        ?.fuel;
                    AbastecimentoFormSheet.show(
                      context,
                      vehicleId: vehicle.id,
                      currentMileageKm: vehicle.currentMileageKm,
                      fuelTypes: vehicle.refueling.offeredFuels,
                      lastFuel: lastFuel,
                    );
                  },
                ),
              AppListRow(
                icon: Icons.speed_outlined,
                title: 'Atualizar quilometragem',
                showChevron: true,
                onTap: () {
                  Navigator.pop(context);
                  OdometerSheet.show(
                    context,
                    vehicleId: vehicle.id,
                    currentMileageKm: vehicle.currentMileageKm,
                  );
                },
              ),
              AppListRow(
                icon: Icons.build_outlined,
                title: 'Registrar manutenção',
                showChevron: true,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.maintenanceNew);
                },
              ),
              AppListRow(
                icon: Icons.receipt_long_outlined,
                title: 'Registrar IPVA',
                showChevron: true,
                onTap: () {
                  Navigator.pop(context);
                  ObligationFormSheet.show(
                    context,
                    vehicleId: vehicle.id,
                    kind: ObligationKind.ipva,
                  );
                },
              ),
              AppListRow(
                icon: Icons.description_outlined,
                title: 'Registrar licenciamento',
                showChevron: true,
                onTap: () {
                  Navigator.pop(context);
                  ObligationFormSheet.show(
                    context,
                    vehicleId: vehicle.id,
                    kind: ObligationKind.licenciamento,
                  );
                },
              ),
              AppListRow(
                icon: Icons.shield_outlined,
                title: 'Registrar seguro',
                showChevron: true,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.seguroNew);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
