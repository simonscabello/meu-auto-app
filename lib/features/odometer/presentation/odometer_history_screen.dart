import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/application/load_more_scroll.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/odometer/application/odometer_provider.dart';
import 'package:meu_auto/features/odometer/domain/odometer_reading.dart';
import 'package:meu_auto/features/vehicle/application/vehicle_derived.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
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
          padding: AppSpacing.screen,
          child: AppSkeletonList(count: 4, itemHeight: 72),
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
      invalidateVehicleDerived(ref, widget.vehicleId);
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
        icon: Icons.speed_outlined,
        title: 'A quilometragem do seu carro começa aqui',
        message:
            'Toque em atualizar quilometragem para registrar a primeira leitura.',
      );
    }

    final months = _groupByMonth(state.items);

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
              for (final reading in month.readings)
                _ReadingTile(
                  key: ValueKey(reading.id),
                  reading: reading,
                  deleting: deletingId == reading.id,
                  onDelete: onDelete,
                  onBlockedDelete: onBlockedDelete,
                ),
            ],
          ),
        );
      },
    );
  }

  /// Groups by month without a second pass over the data: the list already
  /// arrives newest first, so a group closes wherever the month changes.
  List<({String label, List<OdometerReading> readings})> _groupByMonth(
    List<OdometerReading> readings,
  ) {
    final groups = <({String label, List<OdometerReading> readings})>[];
    int? year;
    int? month;
    for (final reading in readings) {
      if (reading.occurredOn.year != year ||
          reading.occurredOn.month != month) {
        year = reading.occurredOn.year;
        month = reading.occurredOn.month;
        groups.add((
          label: formatCivilMonthHeader(reading.occurredOn),
          readings: <OdometerReading>[],
        ));
      }
      groups.last.readings.add(reading);
    }
    return groups;
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({
    super.key,
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
    final scheme = theme.colorScheme;
    final origin = reading.source.originLabel;
    final canDelete = reading.source.isOwnEntry;

    final when = origin == null
        ? formatCivilDate(reading.occurredOn)
        : '${formatCivilDate(reading.occurredOn)} · $origin';

    return AppListRowShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconWell(
            icon: switch (reading.source) {
              OdometerSource.abastecimento => Icons.local_gas_station_outlined,
              OdometerSource.maintenance => Icons.build_outlined,
              _ => Icons.speed_outlined,
            },
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatKm(reading.mileageKm),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  when,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
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
              color: scheme.onSurfaceVariant,
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
