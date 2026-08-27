import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/presentation/obligation_form_sheet.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';

class QuickAddSheet extends ConsumerWidget {
  const QuickAddSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => const QuickAddSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(selectedVehicleProvider).value;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vehicle != null)
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
            if (vehicle != null)
              ListTile(
                leading: const Icon(Icons.build_outlined),
                title: const Text('Registrar manutenção'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.maintenanceNew);
                },
              ),
            if (vehicle != null)
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
            if (vehicle != null)
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
            if (vehicle != null)
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Registrar seguro'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.seguroNew);
                },
              ),
            ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: const Text('Adicionar veículo'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.vehicleNew);
              },
            ),
          ],
        ),
      ),
    );
  }
}
