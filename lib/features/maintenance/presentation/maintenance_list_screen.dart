import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/application/load_more_scroll.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Registrar manutenção',
        onPressed: () => context.push(AppRoutes.maintenanceNew),
        child: const Icon(Icons.add),
      ),
      body: records.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(count: 5, itemHeight: 88),
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
        title: 'O histórico de serviços do seu carro começa aqui',
        message:
            'Cada serviço registrado vira o histórico que o carro leva na revenda.',
        actionLabel: 'Registrar manutenção',
        onAction: onRegister,
      );
    }

    final months = _groupByMonth(state.items);

    return CustomScrollView(
      controller: scroll,
      slivers: [
        for (final month in months) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _MonthHeaderDelegate(label: month.label),
          ),
          SliverList.builder(
            itemCount: month.records.length,
            itemBuilder: (context, index) {
              final record = month.records[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  0,
                  AppSpacing.s16,
                  AppSpacing.s8,
                ),
                child: _RecordTile(record: record, onTap: () => onOpen(record)),
              );
            },
          ),
        ],
        SliverToBoxAdapter(
          child: _Footer(state: state, onRetry: onRetryPage),
        ),
      ],
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

/// Pinned month header. A service history is read by scanning for "when", so
/// the month has to stay on screen while its records scroll under it.
class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MonthHeaderDelegate({required this.label});

  final String label;

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final MaintenanceRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCost = record.totalCostCents.cents > 0;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            maintenanceIconFor(
              record.items.isEmpty ? '' : record.items.first.itemSlug,
            ),
            color: theme.colorScheme.onSurfaceVariant,
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
                const SizedBox(height: AppSpacing.s4),
                Text(
                  '${formatCivilDate(record.occurredOn)} · '
                  '${formatKm(record.mileageKm)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (record.kind == MaintenanceRecordKind.declared) ...[
                  const SizedBox(height: AppSpacing.s8),
                  const _DeclaredChip(),
                ],
              ],
            ),
          ),
          if (showCost) ...[
            const SizedBox(width: AppSpacing.s8),
            Text(
              record.totalCostCents.format(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Marks a record the owner entered from memory rather than from a receipt.
///
/// Deliberately quiet — it is a caveat, not a warning. The record is still
/// history; it just carries less weight in a dispute.
class _DeclaredChip extends StatelessWidget {
  const _DeclaredChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderS,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        'Informado',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
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
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
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
