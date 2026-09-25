import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';
import 'package:meu_auto/features/maintenance/presentation/item_picker_sheet.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_edit_sheet.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/vehicle/application/vehicle_derived.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_detail_header.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_facts_strip.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_overflow_menu.dart';
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
    final current = record.valueOrNull;

    return AppScaffold(
      title: 'Manutenção',
      // Editing is the pencil and deleting is the ⋮, like every detail: the
      // most destructive action used to be one of the two largest shapes on
      // the screen.
      actions: current == null
          ? null
          : [
              AppIconButton(
                label: 'Editar manutenção',
                icon: Icons.edit_outlined,
                onPressed: _busy
                    ? null
                    : () => MaintenanceEditSheet.show(context, record: current),
              ),
              AppOverflowMenu(
                actions: [
                  AppMenuAction(
                    label: 'Excluir manutenção',
                    destructive: true,
                    onSelected: () {
                      if (_busy) return;
                      unawaited(_confirmRetraction(current));
                    },
                  ),
                ],
              ),
            ],
      body: Column(
        children: [
          // The retraction has no button of its own any more to spin, so the
          // wait shows here until the screen closes.
          if (_retracting) const LinearProgressIndicator(),
          Expanded(
            child: record.when(
              loading: () => const Padding(
                padding: AppSpacing.screen,
                child: AppSkeletonList(count: 3, itemHeight: 120),
              ),
              error: (error, _) => AppErrorState.fromError(
                error: error,
                onRetry: () =>
                    ref.invalidate(maintenanceRecordProvider(widget.recordId)),
              ),
              data: (data) => MaintenanceDetailContent(
                record: data,
                addingItem: _addingItem,
                onAddItem: _busy ? null : () => unawaited(_addItems(data)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _busy => _retracting || _addingItem;

  /// Names one more service that was done at the same time.
  ///
  /// Appending only, which is why the picker locks what is already on the
  /// record instead of letting it be unticked: removing a line means deciding
  /// what happens to the clock it was keeping, and that decision has not been
  /// made. Retracting the record is still the way to undo a wrong one.
  Future<void> _addItems(MaintenanceRecord record) async {
    final onRecord = {for (final line in record.items) line.maintenanceItemId};
    final hidden = notApplicableItemIds(
      await ref
          .read(maintenancePlansWithHiddenProvider(record.vehicleId).future)
          .then<AsyncValue<List<MaintenancePlan>>>(AsyncData.new)
          .catchError(
            (Object error, StackTrace stack) =>
                AsyncError<List<MaintenancePlan>>(error, stack),
          ),
    );
    if (!mounted) return;
    final picked = await ItemPickerSheet.show(
      context,
      selected: const [],
      lockedItemIds: onRecord,
      title: 'Adicionar item que faltou',
      hiddenItemIds: hidden,
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() => _addingItem = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(maintenanceRecordRepositoryProvider).addItems(record.id, [
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
      title: 'Excluir esta manutenção?',
      message:
          'Ela sai do histórico do carro, junto com a quilometragem registrada '
          'com ela. Os itens voltam a contar a partir do registro anterior, o '
          'que pode mudar quando eles vencem.\n\n'
          'Não dá para desfazer.',
      confirmLabel: 'Excluir manutenção',
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
      // change with it — the clock of each item falls back to the record
      // before.
      invalidateVehicleDerived(ref, record.vehicleId);
      await ref.read(vehiclesProvider.notifier).reload();
      navigator.pop();
      showAppSnackBar(messenger, message: 'Manutenção excluída.');
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _retracting = false);
      showAppErrorSnackBar(messenger, message: failure.message);
    }
  }
}

/// What the record is, in the few words a title holds: the one item, the two,
/// or the first and how many more. A revisão names the visit by itself.
String maintenanceRecordTitle(MaintenanceRecord record) {
  final items = record.items;
  if (items.isEmpty) return 'Manutenção';
  for (final item in items) {
    if (item.itemSlug == 'revisao') {
      final others = items.length - 1;
      if (others == 0) return item.itemName;
      return others == 1
          ? '${item.itemName} e mais 1 item'
          : '${item.itemName} e mais $others itens';
    }
  }
  if (items.length == 1) return items.first.itemName;
  if (items.length == 2) return '${items[0].itemName} e ${items[1].itemName}';
  final others = items.length - 1;
  return '${items.first.itemName} e mais $others itens';
}

/// The record as pure presentation.
///
/// Nothing here derives anything: `warranty_until` and `warranty_until_km`
/// arrive computed by the server on every read, and the totals arrive summed.
///
/// The header says what was done and where; the strip, when, at what mileage
/// and for how much. The lines are one event, so they are one group — and the
/// row that adds a forgotten one is the last row of it, where it reads as "and
/// one more here".
class MaintenanceDetailContent extends StatelessWidget {
  const MaintenanceDetailContent({
    super.key,
    required this.record,
    this.onAddItem,
    this.addingItem = false,
  });

  final MaintenanceRecord record;

  /// Names one more service that was done at the same time. Appending only —
  /// there is no way to take a line off, because removing one means deciding
  /// what happens to the clock it was keeping.
  final VoidCallback? onAddItem;

  final bool addingItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workshop = record.workshopName?.trim();
    final hasWorkshop = workshop != null && workshop.isNotEmpty;
    final notes = record.notes?.trim();
    final declared = record.kind == MaintenanceRecordKind.declared;
    final km = record.mileageKm;
    final figures = [
      if (km != null)
        AppFact(label: 'Odômetro', value: formatKmNumber(km), unit: 'km'),
      if (record.totalCostCents.cents > 0)
        AppFact(label: 'Total', value: record.totalCostCents.format()),
    ];
    // With nothing to set beside it, the date reads better as a sentence
    // under the title than as a strip of one.
    final showStrip = figures.isNotEmpty;
    final subtitle = [
      if (!showStrip) formatCivilDateLong(record.occurredOn),
      if (hasWorkshop) workshop,
    ].join(' · ');

    return ListView(
      padding: AppSpacing.screenHeaded,
      children: [
        AppDetailHeader(
          title: maintenanceRecordTitle(record),
          subtitle: subtitle.isEmpty ? null : subtitle,
          // Told from memory rather than proven: the difference is
          // load-bearing at resale, so it is said at the top, quietly.
          status: declared ? AppStatus.semPeriodicidade : null,
          statusLabel: declared ? 'Informado' : null,
          phrase: declared ? 'Sem comprovante. Pesa menos numa revenda.' : null,
        ),
        if (showStrip) ...[
          const SizedBox(height: AppSpacing.s24),
          AppFactsStrip(
            facts: [
              AppFact(label: 'Data', value: formatCivilDate(record.occurredOn)),
              ...figures,
            ],
          ),
        ],
        const SizedBox(height: appGroupGap),
        AppGroup(
          title: 'O que foi feito',
          count: record.items.length > 1 ? record.items.length : null,
          children: [
            for (final item in record.items)
              _ItemRow(key: ValueKey(item.id), item: item),
            if (onAddItem != null)
              AppListRow(
                icon: addingItem ? Icons.hourglass_empty : Icons.add,
                iconTone: AppIconWellTone.accent,
                title: 'Adicionar item',
                subtitle: 'Feito junto e que ficou de fora',
                onTap: addingItem ? null : onAddItem,
                showChevron: !addingItem,
              ),
          ],
        ),
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            title: 'Observação',
            dividerIndent: AppGroup.textIndent,
            children: [
              AppListRowShell(
                child: Text(notes, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One line of the record: what was done, what it cost, and what it is
/// warranted for.
///
/// [AppListRowShell] rather than [AppListRow]: the cost is a column of its
/// own and the warranty is a line of its own, which is more than the one line
/// of state a plain row carries. The shell keeps the height, the padding and
/// the 48dp minimum identical to every other row in the app.
class _ItemRow extends StatelessWidget with GroupedRow {
  const _ItemRow({super.key, required this.item});

  final MaintenanceRecordItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = [
      if (item.description != null && item.description!.trim().isNotEmpty)
        item.description!.trim(),
      if (item.partBrand != null && item.partBrand!.trim().isNotEmpty)
        item.partBrand!.trim(),
    ].join(' · ');
    final warranty = _warrantyLine(item);
    final cost = item.costCents;

    return AppListRowShell(
      semanticLabel: [
        item.itemName,
        if (detail.isNotEmpty) detail,
        if (cost != null) cost.format(),
        ?warranty,
      ].join('. '),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconWell(icon: maintenanceIconFor(item.itemSlug)),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName, style: theme.textTheme.titleSmall),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.bodySmall),
                ],
                if (warranty != null) ...[
                  const SizedBox(height: 2),
                  Text(warranty, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (cost != null) ...[
            const SizedBox(width: AppSpacing.s12),
            Text(
              cost.format(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: AppTypography.tabular,
              ),
            ),
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
/// a rule the server owns.
String? _warrantyLine(MaintenanceRecordItem item) {
  if (!item.hasWarranty) return null;
  final until = item.warrantyUntil;
  final untilKm = item.warrantyUntilKm;
  final parts = [
    if (until != null) 'até ${formatCivilDate(until)}',
    if (untilKm != null) 'até ${formatKm(untilKm)}',
  ];
  // "ou" and not "e": whichever comes first ends it.
  return 'Garantia ${parts.join(' ou ')}';
}
