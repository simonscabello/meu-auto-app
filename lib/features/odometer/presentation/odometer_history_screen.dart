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
import 'package:meu_auto/features/odometer/presentation/odometer_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicle_derived.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
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
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

const _updateLabel = 'Atualizar quilometragem';

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
    final vehicle = ref.watch(selectedVehicleProvider).valueOrNull;
    // The sheet starts on the car's current reading, so it needs the car.
    final VoidCallback? onUpdate =
        vehicle == null || vehicle.id != widget.vehicleId
        ? null
        : () => OdometerSheet.show(
            context,
            vehicleId: vehicle.id,
            currentMileageKm: vehicle.currentMileageKm,
            showHistoryLink: false,
          );

    return AppScaffold(
      title: 'Quilometragem',
      actions: [
        if (onUpdate != null)
          AppIconButton(
            label: _updateLabel,
            icon: Icons.add,
            onPressed: onUpdate,
          ),
      ],
      body: history.when(
        loading: () => const Padding(
          padding: AppSpacing.screen,
          child: AppSkeletonList(count: 4, itemHeight: 64),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () =>
              ref.invalidate(odometerHistoryProvider(widget.vehicleId)),
        ),
        data: (state) => OdometerHistoryContent(
          state: state,
          scroll: _scroll,
          deletingId: _deletingId,
          onUpdate: onUpdate,
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
          'Para removê-la, exclua esse registro.',
    );
  }

  Future<void> _confirmDelete(OdometerReading reading) async {
    final confirmed = await confirmAction(
      context,
      title: 'Excluir esta leitura?',
      message:
          '${formatKm(reading.mileageKm)} em '
          '${formatCivilDate(reading.occurredOn)}. '
          'A quilometragem atual do carro pode mudar.',
      confirmLabel: 'Excluir leitura',
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
        message: 'Leitura excluída.',
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

/// The readings as pure presentation: one group per month, newest first,
/// each reading with how far the car went since the one before it.
class OdometerHistoryContent extends StatelessWidget {
  const OdometerHistoryContent({
    super.key,
    required this.state,
    this.scroll,
    this.deletingId,
    this.onUpdate,
    this.onDelete,
    this.onBlockedDelete,
    this.onRetryPage,
  });

  final PagedState<OdometerReading> state;
  final ScrollController? scroll;
  final String? deletingId;
  final VoidCallback? onUpdate;
  final ValueChanged<OdometerReading>? onDelete;
  final ValueChanged<OdometerReading>? onBlockedDelete;
  final VoidCallback? onRetryPage;

  @override
  Widget build(BuildContext context) {
    final readings = state.items;
    if (readings.isEmpty) {
      return AppEmptyState(
        icon: Icons.speed_outlined,
        title: 'Nenhuma leitura registrada',
        message:
            'Cada vez que você atualiza a quilometragem, a leitura aparece '
            'aqui.',
        actionLabel: onUpdate == null ? null : _updateLabel,
        onAction: onUpdate,
      );
    }

    final distances = _distancesSincePrevious(readings);
    final months = groupByMonth<OdometerReading>(
      readings,
      (reading) =>
          (year: reading.occurredOn.year, month: reading.occurredOn.month),
      (reading) => formatCivilMonthHeader(reading.occurredOn),
    );

    return ListView.builder(
      controller: scroll,
      padding: AppSpacing.screen,
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
              for (final reading in month.items)
                OdometerReadingRow(
                  key: ValueKey(reading.id),
                  reading: reading,
                  distanceKm: distances[reading.id],
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
}

/// How far the car went between each reading and the one before it — the
/// next one down the list, which arrives newest first. Presentation only: a
/// difference between two readings the server sent, never a new reading.
///
/// Nothing for the oldest reading loaded while more pages remain (its
/// predecessor has not arrived yet), and nothing when the difference is not
/// forward — a correction after a panel swap goes down, and "−3.000 km"
/// would read as the car driving backwards.
Map<String, int> _distancesSincePrevious(List<OdometerReading> readings) {
  final distances = <String, int>{};
  for (var i = 0; i < readings.length - 1; i++) {
    final delta = readings[i].mileageKm - readings[i + 1].mileageKm;
    if (delta > 0) distances[readings[i].id] = delta;
  }
  return distances;
}

/// One reading: the figure, when and where it came from, and how far the car
/// went since the reading before it.
class OdometerReadingRow extends StatelessWidget with GroupedRow {
  const OdometerReadingRow({
    super.key,
    required this.reading,
    this.distanceKm,
    this.deleting = false,
    this.onDelete,
    this.onBlockedDelete,
  });

  final OdometerReading reading;

  /// Kilometres since the previous reading, when it is known and forward.
  final int? distanceKm;
  final bool deleting;
  final ValueChanged<OdometerReading>? onDelete;
  final ValueChanged<OdometerReading>? onBlockedDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canDelete = reading.source.isOwnEntry;
    final notes = reading.notes?.trim();
    final distance = distanceKm;

    final detail = [
      formatCivilDayMonthAbbrev(reading.occurredOn),
      ?_originOf(reading.source),
      if (distance != null) '+${formatKm(distance)}',
    ].join(dotSep);

    final action = deleting
        ? const Padding(
            padding: EdgeInsets.all(AppSpacing.s12),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        : canDelete
        ? (onDelete == null
              ? null
              : AppIconButton(
                  label: 'Excluir leitura',
                  icon: Icons.delete_outline,
                  color: scheme.onSurfaceVariant,
                  onPressed: () => onDelete!(reading),
                ))
        : (onBlockedDelete == null
              ? null
              : AppIconButton(
                  label: 'Por que não dá para excluir',
                  icon: Icons.lock_outline,
                  // Quieter than the bin: it explains, it does not act.
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  onPressed: () => onBlockedDelete!(reading),
                ));

    return AppListRowShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconWell(icon: _iconOf(reading.source)),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The reading, set as the panel shows it; the unit quieter.
                Text.rich(
                  TextSpan(
                    text: formatKmNumber(reading.mileageKm),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabular,
                    ),
                    children: [
                      TextSpan(
                        text: '${nbsp}km',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: theme.textTheme.bodySmall),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(notes, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: AppSpacing.s4), action],
        ],
      ),
    );
  }
}

IconData _iconOf(OdometerSource source) {
  return switch (source) {
    OdometerSource.abastecimento => Icons.local_gas_station_outlined,
    OdometerSource.maintenance => Icons.build_outlined,
    _ => Icons.speed_outlined,
  };
}

/// Where a reading came from, as a clause beside its date. The glyph says
/// the same, so the clause is one word; a reading the owner typed says
/// nothing, because that is the ordinary case.
String? _originOf(OdometerSource source) {
  return switch (source) {
    OdometerSource.correction => 'Correção',
    OdometerSource.maintenance => 'Manutenção',
    OdometerSource.abastecimento => 'Abastecimento',
    OdometerSource.manual || OdometerSource.desconhecido => null,
  };
}
