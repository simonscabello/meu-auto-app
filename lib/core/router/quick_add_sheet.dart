import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          ListTile(
            leading: const Icon(Icons.directions_car_outlined),
            title: const Text('Adicionar veículo'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.vehicleNew);
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
          const _UpcomingTile(
            icon: Icons.receipt_long_outlined,
            label: 'Registrar IPVA',
          ),
          const _UpcomingTile(
            icon: Icons.assignment_outlined,
            label: 'Registrar licenciamento',
          ),
          const _UpcomingTile(
            icon: Icons.security_outlined,
            label: 'Registrar seguro',
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: const Text('Em breve'),
      enabled: false,
    );
  }
}
