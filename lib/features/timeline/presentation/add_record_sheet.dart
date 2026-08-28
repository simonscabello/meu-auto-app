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

/// What kind of record to add, asked from the one screen where the question
/// makes sense.
///
/// This used to be the app's global "+", parked in the middle of the
/// navigation bar. Three things were wrong with it and all three are fixed by
/// moving it here rather than by restyling it: a control that opens a list of
/// seven things cannot say what it does, it appeared on screens where none of
/// the seven was the obvious next move, and it competed with the four
/// destinations it sat between.
///
/// Histórico is where a choice among record types is the right question,
/// because the history is exactly the place all of them land. Every other
/// screen offers its own single action in its own words: Início updates the
/// mileage, Cuidados adds an item to follow, Abastecimentos registers a fill.
///
/// "Adicionar veículo" is deliberately not here. A vehicle is not an event in
/// a vehicle's history; it lives in the vehicle switcher and in Perfil.
class AddRecordSheet extends ConsumerWidget {
  const AddRecordSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => const AddRecordSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(selectedVehicleProvider).value;
    if (vehicle == null) {
      return const SafeArea(child: SizedBox.shrink());
    }
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                0,
                AppSpacing.s16,
                AppSpacing.s8,
              ),
              child: Text(
                'Adicionar registro',
                style: theme.textTheme.titleMedium,
              ),
            ),
            // Ordered by how often a person actually does each one, not by
            // how the data model is organised.
            if (vehicle.refueling.supported)
              ListTile(
                leading: const Icon(Icons.local_gas_station_outlined),
                title: const Text('Registrar abastecimento'),
                onTap: () {
                  Navigator.pop(context);
                  final lastFuel = ref
                      .read(dashboardProvider(vehicle.id))
                      .value
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
            ListTile(
              leading: const Icon(Icons.speed_outlined),
              title: const Text('Atualizar quilometragem'),
              onTap: () {
                Navigator.pop(context);
                OdometerSheet.show(
                  context,
                  vehicleId: vehicle.id,
                  currentMileageKm: vehicle.currentMileageKm,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.build_outlined),
              title: const Text('Registrar manutenção'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.maintenanceNew);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Registrar IPVA'),
              onTap: () {
                Navigator.pop(context);
                ObligationFormSheet.show(
                  context,
                  vehicleId: vehicle.id,
                  kind: ObligationKind.ipva,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Registrar licenciamento'),
              onTap: () {
                Navigator.pop(context);
                ObligationFormSheet.show(
                  context,
                  vehicleId: vehicle.id,
                  kind: ObligationKind.licenciamento,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Registrar seguro'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.seguroNew);
              },
            ),
          ],
        ),
      ),
    );
  }
}
