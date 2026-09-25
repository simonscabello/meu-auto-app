import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/application/load_more_scroll.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/abastecimento/application/abastecimento_provider.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_list_screen.dart';
import 'package:meu_auto/features/costs/domain/costs_copy.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_list_screen.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';
import 'package:meu_auto/features/timeline/domain/timeline_entry.dart';
import 'package:meu_auto/features/timeline/presentation/add_record_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_context_title.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_paged_footer.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_segmented.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// What the history shows: everything, or one kind of record.
enum HistoryFilter { all, maintenance, fuel }

/// Histórico tab: what was done to the selected car and what it cost.
///
/// One tab, three readings of the same past. "Tudo" is the timeline —
/// services, fills, mileage and taxes in one column — headed by what the car
/// cost; "Manutenções" and "Abastecimentos" are the two lists people most
/// often go looking for on their own. They used to be two screens reachable
/// only through a card at the top of this one.
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  HistoryFilter _filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedVehicleProvider);
    final vehicle = selected.valueOrNull;
    final refuels = vehicle?.refueling.supported ?? false;
    // A car that does not refuel has no fuel list to filter to.
    final filter = !refuels && _filter == HistoryFilter.fuel
        ? HistoryFilter.all
        : _filter;

    return AppScaffold(
      onRefresh: vehicle == null ? null : () => _refresh(vehicle.id, filter),
      body: Column(
        children: [
          VehicleTabHeader(
            title: 'Histórico',
            actions: [
              if (vehicle != null)
                AppIconButton(
                  label: 'Adicionar registro',
                  icon: Icons.add,
                  onPressed: () => AddRecordSheet.show(context),
                ),
            ],
          ),
          if (vehicle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.s16,
              ),
              child: AppSegmented<HistoryFilter>(
                value: filter,
                onChanged: (value) => setState(() => _filter = value),
                options: [
                  const AppSegmentedOption(
                    value: HistoryFilter.all,
                    label: 'Tudo',
                  ),
                  const AppSegmentedOption(
                    value: HistoryFilter.maintenance,
                    label: 'Manutenções',
                  ),
                  if (refuels)
                    const AppSegmentedOption(
                      value: HistoryFilter.fuel,
                      label: 'Abastecimentos',
                    ),
                ],
              ),
            ),
          Expanded(
            child: selected.when(
              loading: () => const _TimelineSkeleton(),
              error: (error, _) => AppErrorState.fromError(
                error: error,
                onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
              ),
              data: (current) => current == null
                  ? const SizedBox.shrink()
                  : switch (filter) {
                      HistoryFilter.all => TimelineView(vehicleId: current.id),
                      HistoryFilter.maintenance => MaintenanceRecordsView(
                        vehicleId: current.id,
                      ),
                      HistoryFilter.fuel => AbastecimentosView(
                        vehicleId: current.id,
                      ),
                    },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh(String vehicleId, HistoryFilter filter) async {
    ref.invalidate(dashboardProvider(vehicleId));
    try {
      switch (filter) {
        case HistoryFilter.all:
          ref.invalidate(timelineProvider(vehicleId));
          await ref.read(timelineProvider(vehicleId).future);
        case HistoryFilter.maintenance:
          ref.invalidate(maintenanceRecordsProvider(vehicleId));
          await ref.read(maintenanceRecordsProvider(vehicleId).future);
        case HistoryFilter.fuel:
          ref.invalidate(abastecimentoHistoryProvider(vehicleId));
          await ref.read(abastecimentoHistoryProvider(vehicleId).future);
      }
    } on Object {
      // The provider already holds the failure; the view renders it.
    }
  }
}

class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
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
      ref.read(timelineProvider(widget.vehicleId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(timelineProvider(widget.vehicleId));
    final dashboard = ref
        .watch(dashboardProvider(widget.vehicleId))
        .valueOrNull;
    final vehicle = ref.watch(selectedVehicleProvider).valueOrNull;
    final refuels = vehicle?.refueling.supported ?? false;

    return history.when(
      loading: () => const _TimelineSkeleton(),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(timelineProvider(widget.vehicleId)),
      ),
      data: (state) => TimelineContent(
        state: state,
        scroll: _scroll,
        header: TimelineSummary.orNull(
          costs: dashboard?.costs,
          lastFill: refuels ? dashboard?.lastAbastecimento : null,
          onCostsTap: () => context.push(AppRoutes.costs),
          onFuelTap: () => context.push(AppRoutes.abastecimentos),
        ),
        onOpen: (entry) {
          final route = routeForTimelineEntry(entry);
          if (route != null) context.push(route);
        },
        onAddRecord: () => AddRecordSheet.show(context),
        onRetryPage: () =>
            ref.read(timelineProvider(widget.vehicleId).notifier).loadMore(),
      ),
    );
  }
}

/// The timeline as pure presentation: what the car cost at the top, then its
/// history, one card per month.
///
/// **A card per month, not per day.** Each day used to be its own card with
/// a rail and a glowing node per event, so a month of fills was a column of
/// boxes and the history read as clutter rather than as a sequence. A month
/// is the unit people remember ("foi em agosto"); the day sits in each row.
///
/// Mileage and money line up as a column: the amount on the right of every
/// row, the mileage in the line under the name.
class TimelineContent extends StatelessWidget {
  const TimelineContent({
    super.key,
    required this.state,
    this.scroll,
    this.onOpen,
    this.onAddRecord,
    this.onRetryPage,
    this.header,
  });

  final PagedState<TimelineEntry> state;
  final ScrollController? scroll;

  /// Shown above the first month — what the car cost, and its fuel.
  final Widget? header;
  final ValueChanged<TimelineEntry>? onOpen;
  final VoidCallback? onAddRecord;
  final VoidCallback? onRetryPage;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.history_outlined,
        title: 'Nenhum registro ainda',
        message:
            'Cada manutenção, abastecimento e pagamento registrado entra '
            'aqui, e vira o histórico que o carro leva na revenda.',
        actionLabel: onAddRecord == null ? null : 'Adicionar registro',
        onAction: onAddRecord,
      );
    }

    final months = groupTimelineByMonth(state.items);

    return ListView.builder(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.tab,
      itemCount: months.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          if (header == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: appGroupGap),
            child: header,
          );
        }
        if (index == months.length + 1) {
          return AppPagedFooter(state: state, onRetry: onRetryPage);
        }
        final month = months[index - 1];
        return Padding(
          padding: EdgeInsets.only(top: index == 1 ? 0 : appGroupGap),
          child: AppGroup(
            title: month.label,
            children: [
              for (final entry in month.items)
                TimelineRow(
                  entry: entry,
                  onTap:
                      onOpen != null && routeForTimelineEntry(entry) != null
                      ? () => onOpen!(entry)
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// What the car cost, and how its fuel is going — the two numbers the
/// history is opened for, as two lines that each lead to their own screen.
///
/// It was two cards: a large total with a paragraph under it, and a "último
/// abastecimento" card with three figures side by side. Five numbers before
/// the first line of history. Now it is one card, one figure per line, and
/// the detail is a tap away.
class TimelineSummary extends StatelessWidget {
  const TimelineSummary({
    super.key,
    this.costs,
    this.lastFill,
    this.onCostsTap,
    this.onFuelTap,
  });

  /// Null when there is nothing to say: no cost registered and no fill.
  static TimelineSummary? orNull({
    DashboardCosts? costs,
    LastAbastecimento? lastFill,
    VoidCallback? onCostsTap,
    VoidCallback? onFuelTap,
  }) {
    final showCosts = costs != null && costs.totalCents.cents > 0;
    if (!showCosts && lastFill == null) return null;
    return TimelineSummary(
      costs: showCosts ? costs : null,
      lastFill: lastFill,
      onCostsTap: onCostsTap,
      onFuelTap: onFuelTap,
    );
  }

  final DashboardCosts? costs;
  final LastAbastecimento? lastFill;
  final VoidCallback? onCostsTap;
  final VoidCallback? onFuelTap;

  @override
  Widget build(BuildContext context) {
    final costs = this.costs;
    final fill = lastFill;
    return AppGroup(
      children: [
        if (costs != null)
          AppListRow(
            icon: Icons.payments_outlined,
            title: costs.periodMonths == 12
                ? 'Gastos em 12 meses'
                : 'Gastos nos ${costWindowLabel(costs.periodMonths)}',
            value: costs.totalCents.format(),
            strongValue: true,
            onTap: onCostsTap,
            showChevron: onCostsTap != null,
          ),
        if (fill != null)
          AppListRow(
            icon: Icons.local_gas_station_outlined,
            title: 'Consumo',
            subtitle:
                'Abastecido em ${formatCivilDayMonthAbbrev(fill.occurredOn)}',
            value: consumptionShortPhrase(fill.consumption) ?? '—',
            strongValue: true,
            onTap: onFuelTap,
            showChevron: onFuelTap != null,
          ),
      ],
    );
  }
}

/// One entry of the history: what, when and how far, and what it cost.
class TimelineRow extends StatelessWidget with GroupedRow {
  const TimelineRow({super.key, required this.entry, this.onTap});

  final TimelineEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amount = entry.amountCents;
    final showAmount = amount != null && amount.cents > 0;
    final mileage = entry.mileageKm;
    // One line: when, and where on the odometer. The workshop, the fuel
    // and the rest are on the entry's own screen; here they wrapped every
    // row onto a third line.
    final detail = [
      formatCivilDayMonthAbbrev(entry.occurredOn),
      if (mileage != null)
        formatKm(mileage)
      else
        ?timelineSubtitleOf(entry),
    ].join(' · ');

    return AppListRow(
      icon: timelineIconOf(entry),
      title: titleOf(entry),
      titleMaxLines: 2,
      subtitle: detail,
      value: showAmount ? amount.format() : null,
      strongValue: true,
      onTap: onTap,
      showChevron: onTap != null,
    );
  }
}

/// The list already arrives newest first, so a group closes wherever the
/// month changes — no sorting, no second pass.
@visibleForTesting
List<({String label, List<TimelineEntry> items})> groupTimelineByMonth(
  List<TimelineEntry> entries,
) {
  return groupByMonth<TimelineEntry>(
    entries,
    (entry) => (year: entry.occurredOn.year, month: entry.occurredOn.month),
    (entry) => formatCivilMonthHeader(entry.occurredOn),
  );
}

/// Where a tap should go. `null` means the row is not tappable — an unknown
/// `kind` has nowhere to land, and inventing a screen would be a guess.
@visibleForTesting
String? routeForTimelineEntry(TimelineEntry entry) {
  return switch (entry.kind) {
    TimelineEntryKind.manutencao => AppRoutes.maintenanceRecord(entry.id),
    TimelineEntryKind.odometro => AppRoutes.odometer,
    TimelineEntryKind.ipva => AppRoutes.obligation(entry.id),
    TimelineEntryKind.licenciamento => AppRoutes.obligation(entry.id),
    TimelineEntryKind.abastecimento => AppRoutes.abastecimento(entry.id),
    TimelineEntryKind.desconhecido => null,
  };
}

IconData timelineIconOf(TimelineEntry entry) {
  if (entry.care == true) return Icons.checklist_rtl_outlined;
  return switch (entry.kind) {
    TimelineEntryKind.manutencao => Icons.build_outlined,
    TimelineEntryKind.odometro => Icons.speed_outlined,
    TimelineEntryKind.ipva => Icons.receipt_long_outlined,
    TimelineEntryKind.licenciamento => Icons.description_outlined,
    TimelineEntryKind.abastecimento => Icons.local_gas_station_outlined,
    TimelineEntryKind.desconhecido => Icons.history_outlined,
  };
}

/// The server's second line for an entry, in the app's words.
String? timelineSubtitleOf(TimelineEntry entry) {
  final raw = entry.subtitle?.trim();
  if (raw == null || raw.isEmpty) return null;
  // A server from before the fix sent the reading's source column as it is:
  // "manual" says nothing, and "correction" reached the screen in English.
  if (entry.kind == TimelineEntryKind.odometro) {
    return switch (raw) {
      'manual' => null,
      'correction' => 'Correção',
      _ => raw,
    };
  }
  if (entry.kind != TimelineEntryKind.abastecimento) return raw;
  final fuel = AbastecimentoFuel.fromWire(raw);
  if (fuel == AbastecimentoFuel.desconhecido) return raw;
  return abastecimentoFuelLabel(fuel);
}

/// Mirrors the timeline: the summary card, a month title, a month card.
class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: AppSpacing.tab,
      children: const [
        AppSkeleton(width: double.infinity, height: 124),
        SizedBox(height: AppSpacing.block),
        AppSkeleton(width: 150, height: 18),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: double.infinity, height: 196),
      ],
    );
  }
}
