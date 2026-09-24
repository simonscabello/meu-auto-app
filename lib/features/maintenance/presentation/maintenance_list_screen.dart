import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/application/load_more_scroll.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';

class MaintenanceListScreen extends ConsumerStatefulWidget {
  const MaintenanceListScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<MaintenanceListScreen> createState() =>
      _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends ConsumerState<MaintenanceListScreen> {
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

    return AppScaffold(
      title: 'Manutenções',
      actions: [
        AppIconButton(
          label: 'Registrar manutenção',
          icon: Icons.add,
          onPressed: () => context.push(AppRoutes.maintenanceNew),
        ),
      ],
      body: records.when(
        loading: () => const Padding(
          padding: AppSpacing.screen,
          child: AppSkeletonList(count: 4, itemHeight: 88),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () =>
              ref.invalidate(maintenanceRecordsProvider(widget.vehicleId)),
        ),
        data: (state) => _RecordList(
          state: state,
          scroll: _scroll,
          onOpen: (record) =>
              context.push(AppRoutes.maintenanceRecord(record.id)),
          onRegister: () => context.push(AppRoutes.maintenanceNew),
          onRetryPage: () => ref
              .read(maintenanceRecordsProvider(widget.vehicleId).notifier)
              .loadMore(),
        ),
      ),
    );
  }
}

class _RecordList extends StatelessWidget {
  const _RecordList({
    required this.state,
    required this.scroll,
    required this.onOpen,
    required this.onRegister,
    required this.onRetryPage,
  });

  final PagedState<MaintenanceRecord> state;
  final ScrollController scroll;
  final ValueChanged<MaintenanceRecord> onOpen;
  final VoidCallback onRegister;
  final VoidCallback onRetryPage;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.build_outlined,
        title: 'O histórico de serviços do seu carro começa aqui',
        message:
            'Cada serviço registrado vira o histórico que o carro leva na revenda.',
        actionLabel: 'Registrar manutenção',
        onAction: onRegister,
      );
    }

    final months = _groupByMonth(state.items);

    // One group per month, the month as its label. A service history is read
    // by scanning for "when", and a bounded surface per month is what makes
    // the boundaries between months visible while scrolling.
    return ListView.builder(
      controller: scroll,
      padding: AppSpacing.screen,
      itemCount: months.length + 1,
      itemBuilder: (context, index) {
        if (index == months.length) {
          return _Footer(state: state, onRetry: onRetryPage);
        }
        final month = months[index];
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : appGroupGap),
          child: AppGroup(
            title: month.label,
            children: [
              for (final record in month.records)
                _RecordTile(record: record, onTap: () => onOpen(record)),
            ],
          ),
        );
      },
    );
  }

  /// The list already arrives newest first, so a group closes wherever the
  /// month changes — no sorting, no second pass.
  List<({String label, List<MaintenanceRecord> records})> _groupByMonth(
    List<MaintenanceRecord> records,
  ) {
    final groups = <({String label, List<MaintenanceRecord> records})>[];
    int? year;
    int? month;
    for (final record in records) {
      if (record.occurredOn.year != year || record.occurredOn.month != month) {
        year = record.occurredOn.year;
        month = record.occurredOn.month;
        groups.add((
          label: formatCivilMonthHeader(record.occurredOn),
          records: <MaintenanceRecord>[],
        ));
      }
      groups.last.records.add(record);
    }
    return groups;
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final MaintenanceRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCost = record.totalCostCents.cents > 0;

    return AppListRowShell(
      onTap: onTap,
      semanticLabel: '${record.itemsSummary}. ${_recordWhen(record)}',
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
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _recordWhen(record),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (record.kind == MaintenanceRecordKind.declared) ...[
                  const SizedBox(height: AppSpacing.s8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppStatusChip(
                      status: AppStatus.semBaseline,
                      label: 'Informado',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showCost) ...[
            const SizedBox(width: AppSpacing.s8),
            Text(
              record.totalCostCents.format(),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.s8),
          Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}

String _recordWhen(MaintenanceRecord record) {
  final km = record.mileageKm;
  if (km == null) return formatCivilDate(record.occurredOn);
  return '${formatCivilDate(record.occurredOn)} · ${formatKm(km)}';
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});

  final PagedState<MaintenanceRecord> state;
  final VoidCallback onRetry;

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
