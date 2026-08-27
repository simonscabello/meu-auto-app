import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ordered by how often it happens, not by how the features were
          // built. Mileage is the pump-side write; a second car is once a year.
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
          ListTile(
            leading: const Icon(Icons.directions_car_outlined),
            title: const Text('Adicionar veículo'),
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.vehicleNew);
            },
          ),
          // One line instead of three rows nobody can tap. The gap is still
          // stated; it just stops taking up half the sheet.
          const _UpcomingNote(),
        ],
      ),
    );
  }
}

class _UpcomingNote extends StatelessWidget {
  const _UpcomingNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      child: Text(
        'IPVA, licenciamento e seguro entram em breve.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
