import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_detail_header.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_fact_row.dart';
import 'package:meu_auto/shared/widgets/app_facts_strip.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_overflow_menu.dart';
import 'package:meu_auto/shared/widgets/app_plate_chip.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
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
      title: 'Excluir este veículo?',
      message:
          'Ele sai das suas listas. O histórico de serviços fica guardado.',
      confirmLabel: 'Excluir veículo',
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
      loading: () =>
          const AppScaffold(title: 'Veículo', body: _VehicleDetailSkeleton()),
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

/// The vehicle as pure presentation, app bar included.
///
/// Public and provider-free for the same reason [DashboardContent] is: it is
/// what the layout tests pump, and a widget that needs a `ProviderScope` to
/// render cannot be checked at 360x640 with the text scaled up.
///
/// No photograph, and nothing waits for one: the car is its name, the plate
/// drawn as a plate, and three figures. Editing is the pencil; deleting is
/// rare and destructive, so it is one entry in the ⋮ followed by a
/// confirmation.
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
    return AppScaffold(
      title: 'Veículo',
      actions: [
        if (onEdit != null)
          AppIconButton(
            label: 'Editar veículo',
            icon: Icons.edit_outlined,
            onPressed: deleting ? null : onEdit,
          ),
        if (deleting)
          const SizedBox(
            width: AppSpacing.minTapTarget,
            height: AppSpacing.minTapTarget,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (onDelete != null)
          AppOverflowMenu(
            actions: [
              AppMenuAction(
                label: 'Excluir veículo',
                destructive: true,
                onSelected: onDelete!,
              ),
            ],
          ),
      ],
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final plate = _text(vehicle.plate);
    final recordedOn = vehicle.currentMileageAt;
    final year = _yearLabel();
    final fuel = vehicle.fuelType;
    final documents = _documentRows();
    final identity = _identityRows();

    return ListView(
      padding: AppSpacing.screenHeaded,
      children: [
        AppDetailHeader(title: vehicle.shortName, subtitle: _subtitle()),
        if (plate != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppPlateChip(plate: plate),
          ),
        ],
        const SizedBox(height: AppSpacing.s24),
        AppFactsStrip(
          facts: [
            AppFact(
              label: 'Odômetro',
              value: formatKmNumber(vehicle.currentMileageKm),
              unit: 'km',
            ),
            if (year != null) AppFact(label: 'Ano', value: year),
            if (fuel != null && fuel != FuelType.desconhecido)
              AppFact(label: 'Combustível', value: fuel.label),
          ],
        ),
        if (recordedOn != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(
              'Odômetro atualizado em ${formatCivilDate(recordedOn)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
        if (documents.isNotEmpty) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            title: 'Documentação',
            dividerIndent: AppGroup.textIndent,
            children: documents,
          ),
        ],
        if (identity.isNotEmpty) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            title: 'Identificação',
            dividerIndent: AppGroup.textIndent,
            children: identity,
          ),
        ],
      ],
    );
  }

  /// What the short name leaves out: the make and the model as registered
  /// when the title is a nickname, or the model's full description when the
  /// title shortened it — and the version, when there is one.
  String? _subtitle() {
    final nickname = _text(vehicle.nickname);
    final model = vehicle.model.trim();
    final version = _text(vehicle.version);
    final parts = [
      if (nickname != null)
        '${vehicle.brand} $model'
      else if (shortModelName(model) != model)
        model,
      ?version,
    ];
    return parts.isEmpty ? null : parts.join(dotSep);
  }

  /// The numbers on the CRLV. The plate is already drawn under the title, so
  /// it is not repeated here; with neither number known, the group keeps a
  /// way to add them rather than disappearing.
  List<Widget> _documentRows() {
    final renavam = _text(vehicle.renavam);
    final chassis = _text(vehicle.chassis);
    return [
      if (renavam != null)
        AppFactRow(label: 'Renavam', value: renavam, inline: true),
      if (chassis != null)
        AppFactRow(label: 'Chassi', value: chassis, inline: true),
      if (renavam == null && chassis == null && onEdit != null)
        AppListRow(
          icon: Icons.add,
          iconTone: AppIconWellTone.accent,
          title: 'Adicionar renavam e chassi',
          onTap: deleting ? null : onEdit,
        ),
    ];
  }

  List<Widget> _identityRows() {
    final version = _text(vehicle.version);
    final color = _text(vehicle.color);
    final nickname = _text(vehicle.nickname);
    final fipe = _text(vehicle.fipeCode);
    return [
      AppFactRow(label: 'Marca', value: vehicle.brand, inline: true),
      AppFactRow(label: 'Modelo', value: vehicle.model, inline: true),
      if (version != null)
        AppFactRow(label: 'Versão', value: version, inline: true),
      if (color != null) AppFactRow(label: 'Cor', value: color, inline: true),
      if (nickname != null)
        AppFactRow(label: 'Apelido', value: nickname, inline: true),
      if (fipe != null)
        AppFactRow(label: 'Código FIPE', value: fipe, inline: true),
    ];
  }

  /// `2017/2018` when the two differ, one figure when they agree or only one
  /// is known. Two cells for two numbers nobody reads separately is padding.
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

String? _text(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

class _VehicleDetailSkeleton extends StatelessWidget {
  const _VehicleDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenHeaded,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        AppSkeleton(width: 200, height: 28),
        SizedBox(height: AppSpacing.s8),
        AppSkeleton(width: 240, height: 18),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: 84, height: 24),
        SizedBox(height: AppSpacing.s24),
        AppSkeleton(width: double.infinity, height: 76),
        SizedBox(height: appGroupGap),
        AppSkeleton(width: 120, height: 18),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: double.infinity, height: 150),
      ],
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
