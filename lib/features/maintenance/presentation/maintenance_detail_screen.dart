import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_edit_sheet.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/odometer/application/odometer_provider.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
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
          onEdit: _retracting
              ? null
              : () => MaintenanceEditSheet.show(context, record: data),
          onRetract: _retracting ? null : () => _confirmRetraction(data),
        ),
      ),
    );
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
class MaintenanceDetailContent extends StatelessWidget {
  const MaintenanceDetailContent({
    super.key,
    required this.record,
    this.onEdit,
    this.onRetract,
    this.retracting = false,
  });

  final MaintenanceRecord record;
  final VoidCallback? onEdit;
  final VoidCallback? onRetract;
  final bool retracting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
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
        const SizedBox(height: AppSpacing.s24),
        AppSectionHeader(
          title: record.items.length == 1
              ? 'O que foi feito'
              : 'O que foi feito (${record.items.length} itens)',
        ),
        const SizedBox(height: AppSpacing.s8),
        for (final item in record.items) ...[
          _ItemCard(item: item),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (record.totalCostCents.cents > 0) ...[
          const SizedBox(height: AppSpacing.s8),
          AppCard(
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
        if (record.notes != null && record.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          const AppSectionHeader(title: 'Observação'),
          const SizedBox(height: AppSpacing.s8),
          Text(record.notes!.trim(), style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.s24),
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

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                maintenanceIconFor(item.itemSlug),
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName, style: theme.textTheme.titleSmall),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
            const SizedBox(height: AppSpacing.s12),
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
