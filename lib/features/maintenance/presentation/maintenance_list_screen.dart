import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/application/load_more_scroll.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
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

/// The services done on the selected car, on a screen of their own — the
/// deep link `/manutencoes`. Histórico shows the same list under its
/// "Manutenções" filter.
class MaintenanceListScreen extends StatelessWidget {
  const MaintenanceListScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Manutenções',
      actions: [
        AppIconButton(
          label: 'Registrar manutenção',
          icon: Icons.add,
          onPressed: () => context.push(AppRoutes.maintenanceNew),
        ),
      ],
      body: MaintenanceRecordsView(
        vehicleId: vehicleId,
        padding: AppSpacing.screen,
      ),
    );
  }
}

/// The paginated list of service records, wherever it is shown.
class MaintenanceRecordsView extends ConsumerStatefulWidget {
  const MaintenanceRecordsView({
    super.key,
    required this.vehicleId,
    this.padding = AppSpacing.tab,
  });

  final String vehicleId;
  final EdgeInsets padding;

  @override
  ConsumerState<MaintenanceRecordsView> createState() =>
      _MaintenanceRecordsViewState();
}

class _MaintenanceRecordsViewState
    extends ConsumerState<MaintenanceRecordsView> {
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
          .read(maintenanceRecordsProvider(widget.vehicleId).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(maintenanceRecordsProvider(widget.vehicleId));

    return records.when(
      loading: () => Padding(
        padding: widget.padding,
        child: const AppSkeletonList(count: 3, itemHeight: 132),
      ),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () =>
            ref.invalidate(maintenanceRecordsProvider(widget.vehicleId)),
      ),
      data: (state) => MaintenanceRecordList(
        state: state,
        scroll: _scroll,
        padding: widget.padding,
        onOpen: (record) =>
            context.push(AppRoutes.maintenanceRecord(record.id)),
        onRegister: () => context.push(AppRoutes.maintenanceNew),
        onRetryPage: () => ref
            .read(maintenanceRecordsProvider(widget.vehicleId).notifier)
            .loadMore(),
      ),
    );
  }
}

/// The records as pure presentation: one card per month, newest first.
class MaintenanceRecordList extends StatelessWidget {
  const MaintenanceRecordList({
    super.key,
    required this.state,
    this.scroll,
    this.padding = AppSpacing.tab,
    this.onOpen,
    this.onRegister,
    this.onRetryPage,
  });

  final PagedState<MaintenanceRecord> state;
  final ScrollController? scroll;
  final EdgeInsets padding;
  final ValueChanged<MaintenanceRecord>? onOpen;
  final VoidCallback? onRegister;
  final VoidCallback? onRetryPage;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.build_outlined,
        title: 'Nenhuma manutenção registrada',
        message:
            'Cada serviço registrado entra no histórico que o carro leva na '
            'revenda.',
        actionLabel: onRegister == null ? null : 'Registrar manutenção',
        onAction: onRegister,
      );
    }

    final months = groupByMonth<MaintenanceRecord>(
      state.items,
      (record) =>
          (year: record.occurredOn.year, month: record.occurredOn.month),
      (record) => formatCivilMonthHeader(record.occurredOn),
    );

    // One card per month, the month as its title. A service history is
    // read by scanning for "when", and a card per month is what makes the
    // boundaries between months visible while scrolling — without the card
    // per service that turned the old history into a stack of boxes.
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
              for (final record in month.items)
                MaintenanceRecordRow(
                  key: ValueKey(record.id),
                  record: record,
                  onTap: onOpen == null ? null : () => onOpen!(record),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One service: what was done, when and at what mileage, and what it cost.
class MaintenanceRecordRow extends StatelessWidget with GroupedRow {
  const MaintenanceRecordRow({super.key, required this.record, this.onTap});

  final MaintenanceRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showCost = record.totalCostCents.cents > 0;
    final when = maintenanceRecordWhen(record);

    return AppListRowShell(
      onTap: onTap,
      semanticLabel: [
        record.itemsSummary,
        when,
        if (showCost) record.totalCostCents.format(),
      ].join('. '),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconWell(
            icon: maintenanceIconFor(
              record.items.isEmpty ? '' : record.items.first.itemSlug,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.itemsSummary,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(when, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (showCost) ...[
            const SizedBox(width: AppSpacing.s12),
            Text(
              record.totalCostCents.format(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
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

/// "21 set · 137.730 km · Informado" — when, where on the odometer, and
/// whether it was told from memory rather than recorded with a receipt.
String maintenanceRecordWhen(MaintenanceRecord record) {
  final km = record.mileageKm;
  return [
    formatCivilDayMonthAbbrev(record.occurredOn),
    if (km != null) formatKm(km),
    if (record.kind == MaintenanceRecordKind.declared) 'Informado',
  ].join(' · ');
}
