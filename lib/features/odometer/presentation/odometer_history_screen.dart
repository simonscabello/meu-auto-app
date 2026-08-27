import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/application/load_more_scroll.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/odometer/application/odometer_provider.dart';
import 'package:meu_auto/features/odometer/domain/odometer_reading.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class OdometerHistoryScreen extends ConsumerStatefulWidget {
  const OdometerHistoryScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<OdometerHistoryScreen> createState() =>
      _OdometerHistoryScreenState();
}

class _OdometerHistoryScreenState extends ConsumerState<OdometerHistoryScreen> {
  final _scroll = ScrollController();
  String? _deletingId;

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
      ref.read(odometerHistoryProvider(widget.vehicleId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(odometerHistoryProvider(widget.vehicleId));

    return AppScaffold(
      title: 'Quilometragem',
      body: history.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(count: 5),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () =>
              ref.invalidate(odometerHistoryProvider(widget.vehicleId)),
        ),
        data: (state) => _HistoryList(
          state: state,
          scroll: _scroll,
          deletingId: _deletingId,
          onDelete: _confirmDelete,
          onBlockedDelete: _explainBlockedDelete,
          onRetryPage: () => ref
              .read(odometerHistoryProvider(widget.vehicleId).notifier)
              .loadMore(),
        ),
      ),
    );
  }

  /// A reading the app did not create belongs to the event that did. Removing
  /// it alone would leave that maintenance record with no mileage behind it.
  ///
  /// The API does not enforce this — the guard is the app's, and it is
  /// recorded in docs/DECISOES-EM-ABERTO.md as a candidate server-side rule.
  void _explainBlockedDelete(OdometerReading reading) {
    final origin = reading.source == OdometerSource.abastecimento
        ? 'um abastecimento'
        : 'uma manutenção';
    showAppSnackBar(
      ScaffoldMessenger.of(context),
      message:
          'Esta leitura foi registrada junto com $origin. '
          'Para removê-la, apague esse registro.',
    );
  }

  Future<void> _confirmDelete(OdometerReading reading) async {
    final confirmed = await confirmAction(
      context,
      title: 'Apagar esta leitura?',
      message:
          '${formatKm(reading.mileageKm)} em '
          '${formatCivilDate(reading.occurredOn)}.\n\n'
          'A leitura some para sempre, e a quilometragem atual do veículo '
          'pode mudar.',
      confirmLabel: 'Apagar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deletingId = reading.id);
    try {
      await ref
          .read(odometerHistoryProvider(widget.vehicleId).notifier)
          .remove(reading.id);
      // Current mileage is derived from these rows, so everything measured in
      // distance moves with them.
      ref.invalidate(dashboardProvider(widget.vehicleId));
      ref.invalidate(timelineProvider(widget.vehicleId));
      ref.invalidate(costsDashboardProvider);
      await ref.read(vehiclesProvider.notifier).reload();
      if (!mounted) return;
      setState(() => _deletingId = null);
      showAppSnackBar(
        ScaffoldMessenger.of(context),
        message: 'Leitura apagada.',
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _deletingId = null);
      showAppErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: failure.message,
      );
    }
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.state,
    required this.scroll,
    required this.deletingId,
    required this.onDelete,
    required this.onBlockedDelete,
    required this.onRetryPage,
  });

  final PagedState<OdometerReading> state;
  final ScrollController scroll;
  final String? deletingId;
  final ValueChanged<OdometerReading> onDelete;
  final ValueChanged<OdometerReading> onBlockedDelete;
  final VoidCallback onRetryPage;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return const AppEmptyState(
        title: 'A quilometragem do seu carro começa aqui',
        message:
            'Toque em atualizar quilometragem para registrar a primeira leitura.',
      );
    }

    final rows = _withMonthHeaders(state.items);

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(AppSpacing.s16),
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == rows.length) {
          return _Footer(state: state, onRetry: onRetryPage);
        }
        final row = rows[index];
        return switch (row) {
          _MonthHeader(:final label) => Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.s16,
              bottom: AppSpacing.s8,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _ReadingRow(:final reading) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: _ReadingTile(
              reading: reading,
              deleting: deletingId == reading.id,
              onDelete: onDelete,
              onBlockedDelete: onBlockedDelete,
            ),
          ),
        };
      },
    );
  }

  /// Groups by month without a second pass over the data: the list already
  /// arrives newest first, so a header goes in wherever the month changes.
  List<_Row> _withMonthHeaders(List<OdometerReading> readings) {
    final rows = <_Row>[];
    int? year;
    int? month;
    for (final reading in readings) {
      if (reading.occurredOn.year != year ||
          reading.occurredOn.month != month) {
        year = reading.occurredOn.year;
        month = reading.occurredOn.month;
        rows.add(_MonthHeader(formatCivilMonthHeader(reading.occurredOn)));
      }
      rows.add(_ReadingRow(reading));
    }
    return rows;
  }
}

sealed class _Row {
  const _Row();
}

final class _MonthHeader extends _Row {
  const _MonthHeader(this.label);
  final String label;
}

final class _ReadingRow extends _Row {
  const _ReadingRow(this.reading);
  final OdometerReading reading;
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({
    required this.reading,
    required this.deleting,
    required this.onDelete,
    required this.onBlockedDelete,
  });

  final OdometerReading reading;
  final bool deleting;
  final ValueChanged<OdometerReading> onDelete;
  final ValueChanged<OdometerReading> onBlockedDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = reading.source.originLabel;
    final canDelete = reading.source.isOwnEntry;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatKm(reading.mileageKm),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  formatCivilDate(reading.occurredOn),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (origin != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    origin,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (reading.notes != null && reading.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(reading.notes!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (deleting)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.s12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            AppIconButton(
              label: canDelete
                  ? 'Apagar leitura'
                  : 'Por que não dá para apagar',
              icon: canDelete ? Icons.delete_outline : Icons.lock_outline,
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () =>
                  canDelete ? onDelete(reading) : onBlockedDelete(reading),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});

  final PagedState<OdometerReading> state;
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
