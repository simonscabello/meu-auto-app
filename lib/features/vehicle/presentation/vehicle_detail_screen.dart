import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  bool _deleting = false;

  Future<void> _delete(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir veículo?'),
          content: const Text(
            'O veículo some das suas listas, mas o histórico de serviços é preservado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(vehiclesProvider.notifier).delete(widget.vehicleId);
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      context.go(AppRoutes.home);
      showAppSnackBar(messenger, message: 'Veículo excluído.');
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Algo deu errado. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(vehiclesProvider);
    return list.when(
      loading: () => const AppScaffold(
        title: 'Veículo',
        body: Padding(
          padding: EdgeInsets.all(AppSpacing.s24),
          child: AppSkeletonList(),
        ),
      ),
      error: (error, _) => AppScaffold(
        title: 'Veículo',
        body: AppErrorState.fromError(
          error: error,
          onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
        ),
      ),
      data: (state) {
        final vehicle = _find(state.vehicles, widget.vehicleId);
        if (vehicle == null) {
          return AppScaffold(
            title: 'Veículo',
            body: AppErrorState(
              message: 'Este veículo não foi encontrado.',
              onRetry: () => context.go(AppRoutes.vehicles),
            ),
          );
        }
        return _VehicleBody(
          vehicle: vehicle,
          deleting: _deleting,
          onEdit: () => context.push(AppRoutes.vehicleEdit(vehicle.id)),
          onDelete: () => _delete(vehicle),
        );
      },
    );
  }
}

class _VehicleBody extends StatelessWidget {
  const _VehicleBody({
    required this.vehicle,
    required this.deleting,
    required this.onEdit,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fuel = vehicle.fuelType;
    final showFuel = fuel != null && fuel != FuelType.desconhecido;
    final hasDocument = vehicle.renavam != null || vehicle.chassis != null;
    return AppScaffold(
      title: vehicle.displayName,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        children: [
          _Row(label: 'Marca', value: vehicle.brand),
          _Row(label: 'Modelo', value: vehicle.model),
          if (vehicle.version != null)
            _Row(label: 'Versão', value: vehicle.version!),
          if (vehicle.manufactureYear != null)
            _Row(
              label: 'Ano de fabricação',
              value: '${vehicle.manufactureYear}',
            ),
          if (vehicle.modelYear != null)
            _Row(label: 'Ano do modelo', value: '${vehicle.modelYear}'),
          if (vehicle.plate != null)
            _Row(label: 'Placa', value: vehicle.plate!),
          if (vehicle.color != null) _Row(label: 'Cor', value: vehicle.color!),
          if (showFuel) _Row(label: 'Combustível', value: fuel.label),
          _Row(
            label: 'Quilometragem atual',
            value: formatKm(vehicle.currentMileageKm),
          ),
          if (vehicle.currentMileageAt != null)
            _Row(
              label: 'Quilometragem em',
              value: formatCivilDate(vehicle.currentMileageAt!),
            ),
          if (hasDocument) ...[
            const SizedBox(height: AppSpacing.s8),
            const AppSectionHeader(title: 'Dados do documento'),
            if (vehicle.renavam != null)
              _Row(label: 'Renavam', value: vehicle.renavam!),
            if (vehicle.chassis != null)
              _Row(label: 'Chassi', value: vehicle.chassis!),
          ],
          const SizedBox(height: AppSpacing.s24),
          AppButton(label: 'Editar', onPressed: deleting ? null : onEdit),
          const SizedBox(height: AppSpacing.s12),
          AppButton(
            label: 'Excluir',
            variant: AppButtonVariant.destructive,
            loading: deleting,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

Vehicle? _find(List<Vehicle> vehicles, String id) {
  for (final vehicle in vehicles) {
    if (vehicle.id == id) {
      return vehicle;
    }
  }
  return null;
}
