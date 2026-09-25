import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/odometer/application/odometer_provider.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_rollback_dialog.dart';
import 'package:meu_auto/features/vehicle/application/vehicle_derived.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_discard_guard.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

/// Updating the mileage is the most frequent write in the app, and it happens
/// standing up, one-handed, next to a pump. A bottom sheet with the field
/// already focused is two taps from Início; a full screen would not be.
class OdometerSheet extends ConsumerStatefulWidget {
  const OdometerSheet({
    super.key,
    required this.vehicleId,
    required this.currentMileageKm,
  });

  final String vehicleId;
  final int currentMileageKm;

  static Future<void> show(
    BuildContext context, {
    required String vehicleId,
    required int currentMileageKm,
  }) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => OdometerSheet(
        vehicleId: vehicleId,
        currentMileageKm: currentMileageKm,
      ),
    );
  }

  @override
  ConsumerState<OdometerSheet> createState() => _OdometerSheetState();
}

class _OdometerSheetState extends ConsumerState<OdometerSheet> {
  late final TextEditingController _mileage;
  final _notes = TextEditingController();

  CivilDate _occurredOn = CivilDate.todayLocal();

  /// Taken on the first submit and kept: a retry after a dropped connection
  /// must be the same reading, not a second one.
  String? _createId;
  bool _showNotes = false;
  bool _submitting = false;
  bool _offline = false;
  String? _fieldError;
  String? _banner;

  late final String _mileageOpenedWith;

  /// A single number, so the sheet still closes by dragging; the back button
  /// asks first once something was typed.
  bool get _isDirty =>
      _mileage.text != _mileageOpenedWith ||
      _notes.text.trim().isNotEmpty ||
      _occurredOn != CivilDate.todayLocal();

  @override
  void initState() {
    super.initState();
    // Prefilled and fully selected: the current reading is the useful starting
    // point, and typing should replace it rather than append to it.
    _mileage = kmController(widget.currentMileageKm);
    _mileageOpenedWith = _mileage.text;
  }

  @override
  void dispose() {
    _mileage.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit({bool force = false}) async {
    final parsed = kmFromField(_mileage.text);
    if (parsed == null) {
      setState(() => _fieldError = 'Informe a quilometragem.');
      return;
    }

    setState(() {
      _submitting = true;
      _fieldError = null;
      _banner = null;
      _offline = false;
    });

    final repository = ref.read(odometerRepositoryProvider);
    _createId ??= repository.nextId();
    try {
      final created = await repository.create(
        vehicleId: widget.vehicleId,
        mileageKm: parsed,
        occurredOn: _occurredOn,
        notes: _notes.text,
        force: force,
        id: _createId,
      );

      // The response already carries the updated vehicle, so the switcher and
      // every mileage prefill are current without a second request. What the
      // server derives from the mileage still has to be refetched: distances to
      // every due date moved, on Início and on Cuidados alike.
      ref.read(vehiclesProvider.notifier).applyUpdated(created.vehicle);
      invalidateVehicleDerived(ref, widget.vehicleId);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showAppSnackBar(
        messenger,
        message: 'Quilometragem atualizada para ${formatKm(parsed)}.',
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _submitting = false);

      final rollback = OdometerRollback.fromFailure(failure);
      if (rollback != null) {
        final override = await showOdometerRollbackDialog(
          context,
          rollback: rollback,
          serverMessage: failure.message,
        );
        if (!mounted) return;
        if (override) {
          await _submit(force: true);
        } else {
          // Back to the field with everything selected, ready to be retyped.
          _mileage.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _mileage.text.length,
          );
        }
        return;
      }

      setState(() {
        _fieldError = ApiFormErrors.fieldsOf(failure)['mileage_km'];
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
    final scheme = Theme.of(context).colorScheme;

    return AppDiscardGuard(
      listenable: Listenable.merge([_mileage, _notes]),
      isDirty: () => _isDirty,
      busy: _submitting,
      child: AppSheetBody(
        children: [
          AppSheetHeader(
            title: 'Atualizar quilometragem',
            closable: false,
            trailing: AppSectionAction(
              label: 'Histórico',
              onPressed: _submitting
                  ? null
                  : () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push(AppRoutes.odometer);
                    },
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          if (_banner != null) AuthFormBanner(message: _banner!),
          // The reading, set as the instrument shows it.
          AppKmField(
            controller: _mileage,
            autofocus: true,
            enabled: !_submitting,
            textStyle: AppTypography.figure(
              size: 32,
              color: scheme.onSurface,
            ),
            textInputAction: _showNotes
                ? TextInputAction.next
                : TextInputAction.done,
            onSubmitted: (_) => _submitting || _showNotes ? null : _submit(),
            errorText: _fieldError,
            helperText: 'Atual: ${formatKm(widget.currentMileageKm)}',
          ),
          const SizedBox(height: AppSpacing.s12),
          AppDateField(
            value: _occurredOn,
            onPick: _pickDate,
            enabled: !_submitting,
          ),
          if (_showNotes) ...[
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
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Adicionar observação',
                icon: Icons.add,
                variant: AppButtonVariant.tertiary,
                onPressed: _submitting
                    ? null
                    : () => setState(() => _showNotes = true),
              ),
            ),
          const SizedBox(height: AppSpacing.s12),
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
