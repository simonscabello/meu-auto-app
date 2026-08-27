import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_metric.dart';
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
    final confirmed = await confirmAction(
      context,
      title: 'Excluir veículo?',
      message:
          'O veículo some das suas listas, mas o histórico de serviços é '
          'preservado.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!confirmed || !mounted) {
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
      showAppErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: failure.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _deleting = false);
      showAppErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: 'Algo deu errado. Tente novamente.',
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
        return VehicleDetailContent(
          vehicle: vehicle,
          deleting: _deleting,
          onEdit: () => context.push(AppRoutes.vehicleEdit(vehicle.id)),
          onDelete: () => _delete(vehicle),
        );
      },
    );
  }
}

/// The vehicle sheet as pure presentation.
///
/// Public and provider-free for the same reason [DashboardContent] is: it is
/// what the layout tests pump, and a widget that needs a `ProviderScope` to
/// render cannot be checked at 360x640 with the text scaled up.
class VehicleDetailContent extends StatelessWidget {
  const VehicleDetailContent({
    super.key,
    required this.vehicle,
    this.deleting = false,
    this.onEdit,
    this.onDelete,
  });

  final Vehicle vehicle;
  final bool deleting;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: vehicle.displayName,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        children: [
          _MileageHeader(vehicle: vehicle),
          const SizedBox(height: AppSpacing.s24),
          const AppSectionHeader(title: 'Ficha do carro'),
          const SizedBox(height: AppSpacing.s8),
          ..._sheetRows(),
          if (_documentRows().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s24),
            const AppSectionHeader(title: 'Documento'),
            const SizedBox(height: AppSpacing.s8),
            ..._documentRows(),
          ],
          const SizedBox(height: AppSpacing.s32),
          AppButton(label: 'Editar', onPressed: deleting ? null : onEdit),
          const SizedBox(height: AppSpacing.s40),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: AppSpacing.s8),
          // Quiet, and below a rule, the way the account deletion sits in the
          // profile. A destructive action does not have to shout to be found,
          // and it should not compete with Editar for the same glance.
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Excluir este veículo',
              variant: AppButtonVariant.tertiary,
              foregroundColor: theme.colorScheme.error,
              loading: deleting,
              onPressed: deleting ? null : onDelete,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sheetRows() {
    final fuel = vehicle.fuelType;
    final showFuel = fuel != null && fuel != FuelType.desconhecido;
    return [
      _Row(label: 'Marca e modelo', value: '${vehicle.brand} ${vehicle.model}'),
      if (vehicle.version != null)
        _Row(label: 'Versão', value: vehicle.version!),
      if (_yearLabel() != null) _Row(label: 'Ano', value: _yearLabel()!),
      if (showFuel) _Row(label: 'Combustível', value: fuel.label),
      if (vehicle.color != null) _Row(label: 'Cor', value: vehicle.color!),
      if (vehicle.plate != null) _Row(label: 'Placa', value: vehicle.plate!),
    ];
  }

  List<Widget> _documentRows() {
    return [
      if (vehicle.renavam != null)
        _Row(label: 'Renavam', value: vehicle.renavam!),
      if (vehicle.chassis != null)
        _Row(label: 'Chassi', value: vehicle.chassis!),
    ];
  }

  /// `2017/2018` when the two differ, one figure when they agree or only one
  /// is known. Two rows for two numbers nobody reads separately is padding.
  String? _yearLabel() {
    final made = vehicle.manufactureYear;
    final model = vehicle.modelYear;
    if (made == null && model == null) return null;
    if (made == null) return '$model';
    if (model == null) return '$made';
    if (made == model) return '$made';
    return '$made/$model';
  }
}

/// The number the owner actually came to check, at the size they read it.
class _MileageHeader extends StatelessWidget {
  const _MileageHeader({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordedOn = vehicle.currentMileageAt;
    final plate = vehicle.plate?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppMetric(
            value: formatKmNumber(vehicle.currentMileageKm),
            unit: 'km',
            label: recordedOn == null
                ? 'Quilometragem atual'
                : 'Quilometragem em ${formatCivilDate(recordedOn)}',
          ),
        ),
        if (plate != null && plate.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderM,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              plate,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: AppTypography.tabular,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Label left, value right. Stacking the two turns a six-line sheet into a
/// screen and a half of scrolling for no gain in legibility.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
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
