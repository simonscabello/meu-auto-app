import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_rollback_dialog.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_discard_guard.dart';
import 'package:meu_auto/shared/widgets/app_form_section.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

/// Edits the event, never its item lines.
///
/// Changing the lines from here would mean replacing the list, and removing
/// one has to decide what happens to the clock it was keeping. Appending a
/// line does not, so that is a separate action on the record itself.
class MaintenanceEditSheet extends ConsumerStatefulWidget {
  const MaintenanceEditSheet({super.key, required this.record});

  final MaintenanceRecord record;

  static Future<void> show(
    BuildContext context, {
    required MaintenanceRecord record,
  }) {
    return showAppSheet<void>(
      context,
      isForm: true,
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
  late final TextEditingController _cost;

  late CivilDate _occurredOn;
  late final List<String> _openedWith;

  List<TextEditingController> get _fields => [
    _mileage,
    _workshop,
    _notes,
    _cost,
  ];

  bool get _isDirty {
    if (_occurredOn != widget.record.occurredOn) return true;
    final fields = _fields;
    for (var i = 0; i < fields.length; i++) {
      if (fields[i].text != _openedWith[i]) return true;
    }
    return false;
  }

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
    _openedWith = [for (final field in _fields) field.text];
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

  Future<void> _submit({bool correction = false}) async {
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
            correction: correction,
          );

      invalidateAfterMaintenanceWrite(ref, record.vehicleId);
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
        final override = await showOdometerRollbackDialog(
          context,
          rollback: rollback,
          serverMessage: failure.message,
        );
        if (!mounted) return;
        if (override) {
          await _submit(correction: true);
        }
        return;
      }

      setState(() {
        _mileageError = ApiFormErrors.fieldsOf(failure)['mileage_km'];
        _banner = ApiFormErrors.bannerOf(
          failure,
          shownFields: const ['mileage_km'],
        );
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
    return AppDiscardGuard(
      listenable: Listenable.merge(_fields),
      isDirty: () => _isDirty,
      busy: _submitting,
      child: AppSheetBody(
        children: [
          // The lines are not edited here — appending one is its own action
          // on the record, and the header says where it is.
          const AppSheetHeader(
            title: 'Editar manutenção',
            subtitle: 'Para incluir um item, use "Adicionar item".',
          ),
          const SizedBox(height: AppSpacing.s16),
          if (_banner != null) AuthFormBanner(message: _banner!),
          AppFormSection(
            title: 'Quando',
            children: [
              AppDateField(
                value: _occurredOn,
                onPick: _pickDate,
                enabled: !_submitting,
              ),
              AppKmField(
                controller: _mileage,
                enabled: !_submitting,
                errorText: _mileageError,
              ),
            ],
          ),
          const AppFormGap(),
          AppFormSection(
            title: 'Onde e quanto',
            children: [
              TextField(
                controller: _workshop,
                enabled: !_submitting,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Oficina',
                  counterText: '',
                ),
              ),
              AppMoneyField(
                controller: _cost,
                label: 'Valor total',
                enabled: !_submitting,
              ),
              TextField(
                controller: _notes,
                enabled: !_submitting,
                maxLength: 500,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _submitting ? null : _submit(),
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  counterText: '',
                ),
              ),
            ],
          ),
          const AppFormGap(),
          AppButton(
            label: _offline ? 'Tentar de novo' : 'Salvar',
            loading: _submitting,
            onPressed: _submit,
            expanded: true,
          ),
        ],
      ),
    );
  }
}
