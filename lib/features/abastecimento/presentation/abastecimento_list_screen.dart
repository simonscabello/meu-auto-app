import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/application/load_more_scroll.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/abastecimento/application/abastecimento_provider.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/domain/volume.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_form_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_paged_footer.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// The fills of the selected car, on a screen of their own — the deep link
/// `/abastecimentos`. Histórico shows the same list under its
/// "Abastecimentos" filter.
class AbastecimentoListScreen extends ConsumerWidget {
  const AbastecimentoListScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(selectedVehicleProvider).valueOrNull;
    final canRegister = vehicle?.refueling.supported ?? false;

    return AppScaffold(
      title: 'Abastecimentos',
      actions: [
        if (canRegister)
          AppIconButton(
            label: abastecimentoRegisterLabel,
            icon: Icons.add,
            onPressed: () => openAbastecimentoForm(context, ref),
          ),
      ],
      body: AbastecimentosView(
        vehicleId: vehicleId,
        padding: AppSpacing.screen,
      ),
    );
  }
}

/// Opens the fill form for the selected car, if it refuels.
void openAbastecimentoForm(BuildContext context, WidgetRef ref) {
  final vehicle = ref.read(selectedVehicleProvider).valueOrNull;
  if (vehicle == null || !vehicle.refueling.supported) return;
  AbastecimentoFormSheet.show(
    context,
    vehicleId: vehicle.id,
    currentMileageKm: vehicle.currentMileageKm,
    fuelTypes: vehicle.refueling.offeredFuels,
  );
}

/// The paginated list of fills, wherever it is shown.
class AbastecimentosView extends ConsumerStatefulWidget {
  const AbastecimentosView({
    super.key,
    required this.vehicleId,
    this.padding = AppSpacing.tab,
  });

  final String vehicleId;
  final EdgeInsets padding;

  @override
  ConsumerState<AbastecimentosView> createState() => _AbastecimentosViewState();
}

class _AbastecimentosViewState extends ConsumerState<AbastecimentosView> {
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

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(abastecimentoHistoryProvider(widget.vehicleId));
    final vehicle = ref.watch(selectedVehicleProvider).valueOrNull;
    final canRegister = vehicle?.refueling.supported ?? false;

    return history.when(
      loading: () => Padding(
        padding: widget.padding,
        child: const AppSkeletonList(count: 3, itemHeight: 132),
      ),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () =>
            ref.invalidate(abastecimentoHistoryProvider(widget.vehicleId)),
      ),
      data: (state) => AbastecimentoListContent(
        state: state,
        scroll: _scroll,
        padding: widget.padding,
        onOpen: (fill) => context.push(AppRoutes.abastecimento(fill.id)),
        onRegister: canRegister
            ? () => openAbastecimentoForm(context, ref)
            : null,
        onRetryPage: () => ref
            .read(abastecimentoHistoryProvider(widget.vehicleId).notifier)
            .loadMore(),
      ),
    );
  }
}

/// The fills as pure presentation: one card per month, newest first.
class AbastecimentoListContent extends StatelessWidget {
  const AbastecimentoListContent({
    super.key,
    required this.state,
    this.scroll,
    this.padding = AppSpacing.screen,
    this.onOpen,
    this.onRegister,
    this.onRetryPage,
  });

  final PagedState<Abastecimento> state;
  final ScrollController? scroll;
  final EdgeInsets padding;
  final ValueChanged<Abastecimento>? onOpen;
  final VoidCallback? onRegister;
  final VoidCallback? onRetryPage;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.local_gas_station_outlined,
        title: abastecimentoEmptyTitle,
        message: abastecimentoEmptyMessage,
        actionLabel: onRegister == null ? null : abastecimentoRegisterLabel,
        onAction: onRegister,
      );
    }

    final months = groupByMonth<Abastecimento>(
      state.items,
      (fill) => (year: fill.occurredOn.year, month: fill.occurredOn.month),
      (fill) => formatCivilMonthHeader(fill.occurredOn),
    );

    return ListView.builder(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: months.length + 1,
      itemBuilder: (context, index) {
        if (index == months.length) {
          return AppPagedFooter(state: state, onRetry: onRetryPage);
        }
        final month = months[index];
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : appGroupGap),
          child: AppGroup(
            title: month.label,
            children: [
              for (final fill in month.items)
                AbastecimentoRow(
                  key: ValueKey(fill.id),
                  fill: fill,
                  onTap: onOpen == null ? null : () => onOpen!(fill),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One fill: the fuel and how much, when and how far it went, and what it
/// cost — the three things someone scans a fuel log for.
class AbastecimentoRow extends StatelessWidget with GroupedRow {
  const AbastecimentoRow({super.key, required this.fill, this.onTap});

  final Abastecimento fill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title =
        '${abastecimentoFuelLabel(fill.fuel)} · '
        '${litersTextFromVolumeMl(fill.volumeMl)} L';
    final consumption = consumptionShortPhrase(fill.consumption);
    final detail = [
      formatCivilDayMonthAbbrev(fill.occurredOn),
      ?consumption,
    ].join(' · ');

    // With the text enlarged the amount goes under the words, as it does
    // in every row (see [AppTypography.isLargeText]).
    final large = AppTypography.isLargeText(context);
    final cost = Text(
      fill.totalCostCents.format(),
      style: theme.textTheme.titleSmall?.copyWith(
        fontFeatures: AppTypography.tabular,
      ),
    );
    return AppListRowShell(
      onTap: onTap,
      semanticLabel: '$title. $detail. ${fill.totalCostCents.format()}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppIconWell(icon: Icons.local_gas_station_outlined),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(detail, style: theme.textTheme.bodySmall),
                if (large) ...[const SizedBox(height: AppSpacing.s4), cost],
              ],
            ),
          ),
          if (!large) ...[const SizedBox(width: AppSpacing.s12), cost],
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ],
        ],
      ),
    );
  }
}
