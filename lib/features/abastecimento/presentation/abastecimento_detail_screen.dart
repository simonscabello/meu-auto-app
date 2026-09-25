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
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_detail_header.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_fact_row.dart';
import 'package:meu_auto/shared/widgets/app_facts_strip.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_overflow_menu.dart';
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
          padding: AppSpacing.screen,
          child: AppSkeletonList(count: 3, itemHeight: 110),
        ),
      ),
      error: (error, _) => AppScaffold(
        title: 'Abastecimento',
        body: AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(abastecimentoProvider(abastecimentoId)),
        ),
      ),
      data: (current) => AppScaffold(
        title: 'Abastecimento',
        actions: [
          AppIconButton(
            label: 'Editar abastecimento',
            icon: Icons.edit_outlined,
            onPressed: () => _edit(context, ref, current),
          ),
          AppOverflowMenu(
            actions: [
              AppMenuAction(
                label: 'Excluir abastecimento',
                destructive: true,
                onSelected: () => _delete(context, ref, current),
              ),
            ],
          ),
        ],
        body: AbastecimentoDetailContent(fill: current),
      ),
    );
  }
}

void _edit(BuildContext context, WidgetRef ref, Abastecimento fill) {
  final vehicle = ref.read(selectedVehicleProvider).valueOrNull;
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

/// The fill as pure presentation: when, the three figures a person compares
/// fill to fill, and the rest as details.
///
/// Editing and deleting are in the app bar — the pencil, and the ⋮ — rather
/// than two full-width buttons under the facts: the most destructive action
/// on the screen was also one of its two largest shapes.
class AbastecimentoDetailContent extends StatelessWidget {
  const AbastecimentoDetailContent({super.key, required this.fill});

  final Abastecimento fill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final station = fill.stationName?.trim();
    final notes = fill.notes?.trim();
    final kmPerLiter = consumptionValueText(fill.consumption);

    return ListView(
      padding: AppSpacing.screenHeaded,
      children: [
        AppDetailHeader(
          title: formatCivilDateLong(fill.occurredOn),
          subtitle:
              '${abastecimentoFuelLabel(fill.fuel)}$dotSep${formatKm(fill.mileageKm)}',
        ),
        const SizedBox(height: AppSpacing.s24),
        AppFactsStrip(
          facts: [
            AppFact(label: 'Total', value: fill.totalCostCents.format()),
            AppFact(
              label: 'Litros',
              value: litersTextFromVolumeMl(fill.volumeMl),
              unit: 'L',
            ),
            // Without a consumption the third column is the price per
            // litre, not a lone dash; the sentence under the strip says why
            // there is no consumption yet.
            if (kmPerLiter != null)
              AppFact(label: 'Consumo', value: kmPerLiter, unit: 'km/L')
            else
              AppFact(
                label: 'Por litro',
                value: fill.pricePerLiterCents.format(),
              ),
          ],
        ),
        if (kmPerLiter == null) ...[
          const SizedBox(height: AppSpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(
              consumptionPhrase(fill.consumption),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
        const SizedBox(height: appGroupGap),
        AppGroup(
          title: 'Detalhes',
          dividerIndent: AppGroup.textIndent,
          children: [
            if (kmPerLiter != null)
              AppFactRow(
                label: 'Preço por litro',
                value: fill.pricePerLiterCents.format(),
                inline: true,
              ),
            AppFactRow(
              label: 'Tanque cheio',
              value: fill.fullTank ? 'Sim' : 'Não',
              inline: true,
            ),
            if (station != null && station.isNotEmpty)
              AppFactRow(label: 'Posto', value: station, inline: true),
            if (notes != null && notes.isNotEmpty)
              AppFactRow(label: 'Observação', value: notes),
          ],
        ),
      ],
    );
  }
}
