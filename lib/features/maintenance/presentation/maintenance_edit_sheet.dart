import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/odometer/application/odometer_provider.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_rollback_dialog.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

/// Edits the event, never its item lines — the contract does not allow the
/// second, and offering something that fails is worse than not offering it.
class MaintenanceEditSheet extends ConsumerStatefulWidget {
  const MaintenanceEditSheet({super.key, required this.record});

  final MaintenanceRecord record;

  static Future<void> show(
    BuildContext context, {
    required MaintenanceRecord record,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => MaintenanceEditSheet(record: record),
    );
  }

  @override
  ConsumerState<MaintenanceEditSheet> createState() =>
      _MaintenanceEditSheetState();
}

class _MaintenanceEditSheetState extends ConsumerState<MaintenanceEditSheet> {
  late final TextEditingController _mileage;
  late final TextEditingController _workshop;
  late final TextEditingController _notes;

  /// Money fills from the cents up, the way a card machine takes it, and the
  /// field wears `R$ 420,00` as it is typed. No decimal separator to get
  /// wrong, and no double anywhere near the value.
  late final TextEditingController _cost;

  late CivilDate _occurredOn;
  bool _submitting = false;
  bool _offline = false;
  String? _mileageError;
  String? _banner;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _occurredOn = record.occurredOn;
    _mileage = record.mileageKm == null
        ? TextEditingController()
        : kmController(record.mileageKm!);
    _workshop = TextEditingController(text: record.workshopName ?? '');
    _notes = TextEditingController(text: record.notes ?? '');
    _cost = TextEditingController(
      text: record.totalCostCents.cents == 0
          ? ''
          : record.totalCostCents.format(),
    );
  }

  @override
  void dispose() {
    _mileage.dispose();
    _workshop.dispose();
    _notes.dispose();
    _cost.dispose();
    super.dispose();
  }

  Money get _typedCost => Money.fromCents(centsFromMoneyField(_cost.text) ?? 0);

  Future<void> _submit() async {
    final mileage = kmFromField(_mileage.text);
    if (mileage == null) {
      setState(() => _mileageError = 'Informe a quilometragem.');
      return;
    }

    setState(() {
      _submitting = true;
      _mileageError = null;
      _banner = null;
      _offline = false;
    });

    final record = widget.record;
    try {
      await ref
          .read(maintenanceRecordRepositoryProvider)
          .update(
            record.id,
            // Only what actually changed. An absent field stays as it is, so
            // sending everything would be noise the server has to re-validate.
            occurredOn: _occurredOn == record.occurredOn ? null : _occurredOn,
            mileageKm: mileage == record.mileageKm ? null : mileage,
            workshopName: _workshop.text.trim() == (record.workshopName ?? '')
                ? null
                : _workshop.text.trim(),
            totalCost: _typedCost.cents == record.totalCostCents.cents
                ? null
                : _typedCost,
            notes: _notes.text.trim() == (record.notes ?? '')
                ? null
                : _notes.text.trim(),
          );

      ref.invalidate(maintenanceRecordProvider(record.id));
      ref.invalidate(maintenanceRecordsProvider(record.vehicleId));
      ref.invalidate(dashboardProvider(record.vehicleId));
      ref.invalidate(odometerHistoryProvider(record.vehicleId));
      ref.invalidate(timelineProvider(record.vehicleId));
      ref.invalidate(costsDashboardProvider);
      await ref.read(vehiclesProvider.notifier).reload();

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showAppSnackBar(messenger, message: 'Manutenção atualizada.');
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _submitting = false);

      // Moving the date or the mileage moves the odometer reading this record
      // produced, so the same rule applies and the same dialog answers it.
      final rollback = OdometerRollback.fromFailure(failure);
      if (rollback != null) {
        // No override here: PATCH on a maintenance record takes no `source`,
        // so the only honest way out is fixing the value.
        await showOdometerRollbackDialog(
          context,
          rollback: rollback,
          serverMessage: failure.message,
          allowOverride: false,
        );
        return;
      }

      setState(() {
        _mileageError = ApiFormErrors.fieldsOf(failure)['mileage_km'];
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await pickPastDate(context, initial: _occurredOn);
    if (picked == null || !mounted) return;
    setState(() => _occurredOn = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.s24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Editar manutenção', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Os itens desta manutenção não podem ser alterados.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            AppDateField(
              value: _occurredOn,
              onPick: _pickDate,
              enabled: !_submitting,
            ),
            const SizedBox(height: AppSpacing.s12),
            AppKmField(
              controller: _mileage,
              enabled: !_submitting,
              errorText: _mileageError,
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _workshop,
              enabled: !_submitting,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Oficina',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            AppMoneyField(
              controller: _cost,
              label: 'Valor total',
              enabled: !_submitting,
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _notes,
              enabled: !_submitting,
              maxLength: 500,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitting ? null : _submit(),
              decoration: const InputDecoration(
                labelText: 'Observação',
                counterText: '',
              ),
            ),
            if (_banner != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                _banner!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: _offline ? 'Tentar de novo' : 'Salvar',
                loading: _submitting,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
