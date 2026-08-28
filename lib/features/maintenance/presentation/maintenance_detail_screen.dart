import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';
import 'package:meu_auto/features/maintenance/presentation/item_picker_sheet.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_edit_sheet.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/odometer/application/odometer_provider.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class MaintenanceDetailScreen extends ConsumerStatefulWidget {
  const MaintenanceDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState
    extends ConsumerState<MaintenanceDetailScreen> {
  bool _retracting = false;
  bool _addingItem = false;

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(maintenanceRecordProvider(widget.recordId));

    return AppScaffold(
      title: 'Manutenção',
      body: record.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(count: 4, itemHeight: 96),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () =>
              ref.invalidate(maintenanceRecordProvider(widget.recordId)),
        ),
        data: (data) => MaintenanceDetailContent(
          record: data,
          retracting: _retracting,
          addingItem: _addingItem,
          onEdit: _busy
              ? null
              : () => MaintenanceEditSheet.show(context, record: data),
          onRetract: _busy ? null : () => _confirmRetraction(data),
          onAddItem: _busy ? null : () => unawaited(_addItems(data)),
        ),
      ),
    );
  }

  bool get _busy => _retracting || _addingItem;

  /// Names one more service that was done at the same time.
  ///
  /// The case it exists for: a revisão registered with five items, and the
  /// brake fluid remembered afterwards. Before this the only ways out were to
  /// leave the history wrong or to retract the whole record and type all six
  /// lines again.
  ///
  /// Appending only, which is why the picker locks what is already on the
  /// record instead of letting it be unticked: removing a line means deciding
  /// what happens to the clock it was keeping, and that decision has not been
  /// made. Retracting the record is still the way to undo a wrong one.
  Future<void> _addItems(MaintenanceRecord record) async {
    final onRecord = {for (final line in record.items) line.maintenanceItemId};
    final picked = await ItemPickerSheet.show(
      context,
      selected: const [],
      lockedItemIds: onRecord,
      title: 'Adicionar item que faltou',
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() => _addingItem = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(maintenanceRecordRepositoryProvider)
          .addItems(record.id, [
            for (final item in picked) MaintenanceRecordLineDraft(item: item),
          ]);

      // Every clock the new lines reset moved, so the same invalidation a new
      // record triggers applies here — plus this record itself, which is the
      // screen being looked at.
      ref.invalidate(maintenanceRecordProvider(record.id));
      invalidateAfterMaintenanceWrite(ref, record.vehicleId);

      if (!mounted) return;
      setState(() => _addingItem = false);
      showAppSnackBar(
        messenger,
        message: picked.length == 1
            ? 'Item adicionado.'
            : '${picked.length} itens adicionados.',
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _addingItem = false);
      showAppErrorSnackBar(
        messenger,
        message: ApiFormErrors.bannerOf(failure) ?? failure.message,
      );
    }
  }

  Future<void> _confirmRetraction(MaintenanceRecord record) async {
    final confirmed = await confirmAction(
      context,
      title: 'Retratar esta manutenção?',
      message:
          'Ela sai do histórico do carro.\n\n'
          'A quilometragem que você registrou junto com ela também é removida, '
          'e os itens envolvidos voltam a contar a partir do registro anterior '
          '— o que pode mudar quando eles vencem.\n\n'
          'Não dá para desfazer.',
      confirmLabel: 'Retratar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _retracting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(maintenanceRecordsProvider(record.vehicleId).notifier)
          .retract(record.id);
      // Everything the record was holding up moves: the odometer reading it
      // produced is gone, so current mileage and every distance-based due date
      // change with it.
      ref.invalidate(dashboardProvider(record.vehicleId));
      ref.invalidate(odometerHistoryProvider(record.vehicleId));
      ref.invalidate(timelineProvider(record.vehicleId));
      ref.invalidate(costsDashboardProvider);
      await ref.read(vehiclesProvider.notifier).reload();
      navigator.pop();
      showAppSnackBar(messenger, message: 'Manutenção retratada.');
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _retracting = false);
      showAppErrorSnackBar(messenger, message: failure.message);
    }
  }
}

String _recordMileageLine(MaintenanceRecord record) {
  final workshop = record.workshopName?.trim();
  final km = record.mileageKm;
  final parts = <String>[
    if (km != null) formatKm(km),
    if (workshop != null && workshop.isNotEmpty) workshop,
  ];
  return parts.join(' · ');
}

/// The record as pure presentation.
///
/// Nothing here derives anything: `warranty_until` and `warranty_until_km`
/// arrive computed by the server on every read, and the totals arrive summed.
/// The record as pure presentation.
///
/// Nothing here derives anything: `warranty_until` and `warranty_until_km`
/// arrive computed by the server on every read, and the totals arrive summed.
///
/// The lines were a stack of one card per item, which made a revisão of six
/// services read as six separate events. They are one event, so they are one
/// group — and the row that adds a forgotten one is the last row of it, where
/// it reads as "and one more here".
class MaintenanceDetailContent extends StatelessWidget {
  const MaintenanceDetailContent({
    super.key,
    required this.record,
    this.onEdit,
    this.onRetract,
    this.onAddItem,
    this.retracting = false,
    this.addingItem = false,
  });

  final MaintenanceRecord record;
  final VoidCallback? onEdit;
  final VoidCallback? onRetract;

  /// Names one more service that was done at the same time. Appending only —
  /// there is no way to take a line off, because removing one means deciding
  /// what happens to the clock it was keeping.
  final VoidCallback? onAddItem;

  final bool retracting;
  final bool addingItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: [
        Text(
          formatCivilDateLong(record.occurredOn),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          _recordMileageLine(record),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (record.kind == MaintenanceRecordKind.declared) ...[
          const SizedBox(height: AppSpacing.s16),
          const _DeclaredBanner(),
        ],
        const SizedBox(height: appGroupGap),
        AppGroup(
          title: 'O que foi feito',
          count: record.items.length > 1 ? record.items.length : null,
          children: [
            for (final item in record.items) _ItemRow(item: item),
            if (onAddItem != null)
              AppListRow(
                icon: addingItem ? Icons.hourglass_empty : Icons.add,
                title: 'Adicionar item que faltou',
                subtitle: 'Um serviço feito junto e que ficou de fora',
                onTap: addingItem ? null : onAddItem,
                showChevron: !addingItem,
              ),
          ],
        ),
        if (record.totalCostCents.cents > 0) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            dividerIndent: 0,
            children: [
              AppListRowShell(
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Total', style: theme.textTheme.titleSmall),
                    ),
                    Text(
                      record.totalCostCents.format(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (record.notes != null && record.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            title: 'Observação',
            dividerIndent: 0,
            children: [
              AppListRowShell(
                child: Text(
                  record.notes!.trim(),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: appGroupGap),
        if (onEdit != null)
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar'),
          ),
        const SizedBox(height: AppSpacing.s8),
        if (onRetract != null)
          AppButton(
            label: 'Retratar manutenção',
            variant: AppButtonVariant.destructive,
            loading: retracting,
            onPressed: onRetract,
          ),
      ],
    );
  }
}

class _DeclaredBanner extends StatelessWidget {
  const _DeclaredBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = statusColors(AppStatus.semBaseline, theme.brightness);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: AppRadius.borderM,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: visual.foreground),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              'Informado pelo dono, sem comprovante. Conta como histórico, mas '
              'pesa menos numa revenda ou numa discussão com a oficina.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: visual.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the record: what was done, what it cost, and what it is
/// warranted for.
///
/// [AppListRowShell] rather than [AppListRow]: the cost is a column of its
/// own and the warranty is a second line, which is more than the one line of
/// state a plain row carries. The shell keeps the height, the padding and the
/// 48dp minimum identical to every other row in the app.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final MaintenanceRecordItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detail = [
      if (item.description != null && item.description!.trim().isNotEmpty)
        item.description!.trim(),
      if (item.partBrand != null && item.partBrand!.trim().isNotEmpty)
        item.partBrand!.trim(),
    ].join(' · ');

    return AppListRowShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  maintenanceIconFor(item.itemSlug),
                  size: 22,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName, style: theme.textTheme.bodyLarge),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.costCents != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Text(
                  item.costCents!.format(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ],
          ),
          if (item.hasWarranty) ...[
            const SizedBox(height: AppSpacing.s8),
            _WarrantyLine(item: item),
          ],
        ],
      ),
    );
  }
}


/// States the warranty as fact, and stops there.
///
/// It says "até 20/08/2028", never "ativa" or "vencida". Deciding that would
/// mean comparing to today, and whether a warranty is close to running out is
/// a rule the server owns — it already answers it in `/alerts` with
/// `kind: garantia`. Computing it here a second way is how a screen starts
/// disagreeing with the alert list.
class _WarrantyLine extends StatelessWidget {
  const _WarrantyLine({required this.item});

  final MaintenanceRecordItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final until = item.warrantyUntil;
    final untilKm = item.warrantyUntilKm;

    final parts = [
      if (until != null) 'até ${formatCivilDate(until)}',
      if (untilKm != null) 'até ${formatKm(untilKm)}',
    ];

    return Row(
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            // "ou" and not "e": whichever comes first ends it.
            'Garantia ${parts.join(' ou ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
