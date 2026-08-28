import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/application/load_more_scroll.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/abastecimento/application/abastecimento_provider.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/domain/volume.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_form_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

class AbastecimentoListScreen extends ConsumerStatefulWidget {
  const AbastecimentoListScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<AbastecimentoListScreen> createState() =>
      _AbastecimentoListScreenState();
}

class _AbastecimentoListScreenState
    extends ConsumerState<AbastecimentoListScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (shouldLoadMore(_scroll)) {
      ref
          .read(abastecimentoHistoryProvider(widget.vehicleId).notifier)
          .loadMore();
    }
  }

  void _openForm() {
    final vehicle = ref.read(selectedVehicleProvider).value;
    if (vehicle == null) return;
    AbastecimentoFormSheet.show(
      context,
      vehicleId: vehicle.id,
      currentMileageKm: vehicle.currentMileageKm,
      fuelTypes: vehicle.refueling.offeredFuels,
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(abastecimentoHistoryProvider(widget.vehicleId));
    final vehicle = ref.watch(selectedVehicleProvider).value;
    final canRegister = vehicle?.refueling.supported ?? false;

    return AppScaffold(
      title: 'Abastecimentos',
      // In the app bar, not a floating button. Every screen in the app now
      // puts its one action in the same place and names it, so "add" stops
      // being a symbol the reader has to decode per screen.
      actions: [
        if (canRegister)
          AppIconButton(
            label: abastecimentoRegisterLabel,
            icon: Icons.add,
            onPressed: _openForm,
          ),
      ],
      body: history.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(count: 5, itemHeight: 56),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () =>
              ref.invalidate(abastecimentoHistoryProvider(widget.vehicleId)),
        ),
        data: (state) => AbastecimentoListContent(
          state: state,
          scroll: _scroll,
          onOpen: (fill) => context.push(AppRoutes.abastecimento(fill.id)),
          onRegister: canRegister ? _openForm : null,
          onRetryPage: () => ref
              .read(abastecimentoHistoryProvider(widget.vehicleId).notifier)
              .loadMore(),
        ),
      ),
    );
  }
}

class AbastecimentoListContent extends StatelessWidget {
  const AbastecimentoListContent({
    super.key,
    required this.state,
    this.scroll,
    this.onOpen,
    this.onRegister,
    this.onRetryPage,
  });

  final PagedState<Abastecimento> state;
  final ScrollController? scroll;
  final ValueChanged<Abastecimento>? onOpen;
  final VoidCallback? onRegister;
  final VoidCallback? onRetryPage;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return AppEmptyState(
        title: abastecimentoEmptyTitle,
        message: abastecimentoEmptyMessage,
        actionLabel: onRegister == null ? null : abastecimentoRegisterLabel,
        onAction: onRegister,
      );
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      itemCount: state.items.length + 1,
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return _Footer(state: state, onRetry: onRetryPage);
        }
        final fill = state.items[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (index > 0) const AppRowDivider(),
            _FillTile(fill: fill, onTap: () => onOpen?.call(fill)),
          ],
        );
      },
    );
  }
}

/// One fill, as a row.
///
/// Built here rather than from `AppListRow` because this list has a genuine
/// third line: when the server could not work out a consumption it says why,
/// and that sentence is the content of the screen rather than metadata on it.
/// A row that computed cleanly puts its km/L in the figures column instead,
/// beside the amount, where the numbers line up down the page.
class _FillTile extends StatelessWidget {
  const _FillTile({required this.fill, this.onTap});

  final Abastecimento fill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kmPerLiter = consumptionValueText(fill.consumption);

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.local_gas_station_outlined,
            size: 22,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatCivilDate(fill.occurredOn),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 2),
              Text(
                '${abastecimentoFuelLabel(fill.fuel)} · '
                '${litersTextFromVolumeMl(fill.volumeMl)} L',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (kmPerLiter == null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  consumptionPhrase(fill.consumption),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fill.totalCostCents.format(),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
            ),
            if (kmPerLiter != null)
              Text(
                consumptionPhrase(fill.consumption),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
          ],
        ),
      ],
    );

    return AppListRowShell(
      onTap: onTap,
      semanticLabel:
          '${formatCivilDate(fill.occurredOn)}. '
          '${abastecimentoFuelLabel(fill.fuel)}. '
          '${fill.totalCostCents.format()}',
      child: body,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, this.onRetry});

  final PagedState<Abastecimento> state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.lastPageError != null) {
      final error = state.lastPageError;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
        child: Column(
          children: [
            Text(
              error is ApiFailure
                  ? error.message
                  : 'Não foi possível carregar mais.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            AppButton(
              label: 'Tentar de novo',
              variant: AppButtonVariant.tertiary,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox(height: AppSpacing.s24);
  }
}
