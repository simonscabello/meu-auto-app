import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/abastecimento/application/abastecimento_provider.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/domain/volume.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_form_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class AbastecimentoDetailScreen extends ConsumerWidget {
  const AbastecimentoDetailScreen({super.key, required this.abastecimentoId});

  final String abastecimentoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fill = ref.watch(abastecimentoProvider(abastecimentoId));

    return fill.when(
      loading: () => const AppScaffold(
        title: 'Abastecimento',
        body: Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(count: 4, itemHeight: 88),
        ),
      ),
      error: (error, _) => AppScaffold(
        title: 'Abastecimento',
        body: AppErrorState.fromError(
          error: error,
          onRetry: () =>
              ref.invalidate(abastecimentoProvider(abastecimentoId)),
        ),
      ),
      data: (current) => AppScaffold(
        title: 'Abastecimento',
        body: AbastecimentoDetailContent(
          fill: current,
          onEdit: () => _edit(context, ref, current),
          onDelete: () => _delete(context, ref, current),
        ),
      ),
    );
  }
}

void _edit(BuildContext context, WidgetRef ref, Abastecimento fill) {
  final vehicle = ref.read(selectedVehicleProvider).value;
  AbastecimentoFormSheet.show(
    context,
    vehicleId: fill.vehicleId,
    currentMileageKm: vehicle?.currentMileageKm ?? fill.mileageKm,
    fuelTypes: vehicle?.refueling.offeredFuels ?? [fill.fuel],
    lastFuel: fill.fuel,
    existing: fill,
  );
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  Abastecimento fill,
) async {
  final confirmed = await confirmAction(
    context,
    title: abastecimentoDeleteTitle,
    message: abastecimentoDeleteMessage,
    confirmLabel: 'Excluir',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await ref.read(abastecimentoRepositoryProvider).delete(fill.id);
    invalidateAfterAbastecimentoWrite(ref, fill.vehicleId);
    navigator.pop();
    showAppSnackBar(messenger, message: abastecimentoDeletedMessage);
  } on ApiFailure catch (failure) {
    showAppErrorSnackBar(
      messenger,
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

class AbastecimentoDetailContent extends StatelessWidget {
  const AbastecimentoDetailContent({
    super.key,
    required this.fill,
    this.onEdit,
    this.onDelete,
  });

  final Abastecimento fill;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final station = fill.stationName?.trim();
    final notes = fill.notes?.trim();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        Text(
          formatCivilDateLong(fill.occurredOn),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          consumptionPhrase(fill.consumption),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.s24),
        _Fact(label: 'Quilometragem', value: formatKm(fill.mileageKm)),
        const SizedBox(height: AppSpacing.s16),
        _Fact(
          label: 'Litros',
          value: '${litersTextFromVolumeMl(fill.volumeMl)} L',
        ),
        const SizedBox(height: AppSpacing.s16),
        _Fact(label: 'Valor total', value: fill.totalCostCents.format()),
        const SizedBox(height: AppSpacing.s16),
        _Fact(
          label: 'Preço por litro',
          value: fill.pricePerLiterCents.format(),
        ),
        const SizedBox(height: AppSpacing.s16),
        _Fact(label: 'Combustível', value: abastecimentoFuelLabel(fill.fuel)),
        const SizedBox(height: AppSpacing.s16),
        _Fact(
          label: 'Tanque cheio',
          value: fill.fullTank ? 'Sim' : 'Não',
        ),
        if (station != null && station.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          _Fact(label: 'Posto', value: station),
        ],
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          _Fact(label: 'Observação', value: notes),
        ],
        const SizedBox(height: AppSpacing.s32),
        if (onEdit != null) ...[
          AppButton(
            label: 'Editar',
            variant: AppButtonVariant.secondary,
            onPressed: onEdit,
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (onDelete != null)
          AppButton(
            label: 'Excluir',
            variant: AppButtonVariant.destructive,
            onPressed: onDelete,
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
