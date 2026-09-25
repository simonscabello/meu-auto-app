import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/abastecimento/application/abastecimento_provider.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/domain/volume.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_rollback_dialog.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_discard_guard.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_segmented.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:meu_auto/shared/widgets/app_switch_row.dart';

/// Registering a fill happens standing at the pump, with the receipt in one
/// hand. So the sheet is read in the order the facts are at hand: which fuel
/// (already chosen), what the pump says, what the panel says, and whether
/// the tank was filled. The date is today unless someone changes it, and the
/// station and a note are behind one tap.
class AbastecimentoFormSheet extends ConsumerStatefulWidget {
  const AbastecimentoFormSheet({
    super.key,
    required this.vehicleId,
    required this.currentMileageKm,
    required this.fuelTypes,
    this.lastFuel,
    this.existing,
    this.newId,
  });

  final String vehicleId;
  final int currentMileageKm;
  final List<AbastecimentoFuel> fuelTypes;
  final AbastecimentoFuel? lastFuel;
  final Abastecimento? existing;
  final String Function()? newId;

  static Future<void> show(
    BuildContext context, {
    required String vehicleId,
    required int currentMileageKm,
    required List<AbastecimentoFuel> fuelTypes,
    AbastecimentoFuel? lastFuel,
    Abastecimento? existing,
    String Function()? newId,
  }) {
    // A form: closes through its header or the back button, which both ask
    // before discarding.
    return showAppSheet<void>(
      context,
      isForm: true,
      builder: (sheetContext) => AbastecimentoFormSheet(
        vehicleId: vehicleId,
        currentMileageKm: currentMileageKm,
        fuelTypes: fuelTypes,
        lastFuel: lastFuel,
        existing: existing,
        newId: newId,
      ),
    );
  }

  @override
  ConsumerState<AbastecimentoFormSheet> createState() =>
      _AbastecimentoFormSheetState();
}

class _AbastecimentoFormSheetState
    extends ConsumerState<AbastecimentoFormSheet> {
  late final String _createId;
  late final TextEditingController _mileage;
  late final TextEditingController _liters;
  late final TextEditingController _cost;
  late final TextEditingController _station;
  late final TextEditingController _notes;

  late CivilDate _occurredOn;
  late bool _fullTank;
  AbastecimentoFuel? _fuel;
  late bool _showDetails;
  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  bool get _editing => widget.existing != null;

  late final List<String> _openedWith;
  late final CivilDate _dateOpenedWith;
  late final bool _fullTankOpenedWith;
  AbastecimentoFuel? _fuelOpenedWith;

  List<TextEditingController> get _fields => [
    _mileage,
    _liters,
    _cost,
    _station,
    _notes,
  ];

  bool get _isDirty {
    if (_occurredOn != _dateOpenedWith) return true;
    if (_fullTank != _fullTankOpenedWith) return true;
    if (_fuel != _fuelOpenedWith) return true;
    final fields = _fields;
    for (var i = 0; i < fields.length; i++) {
      if (fields[i].text != _openedWith[i]) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _createId = widget.newId?.call() ?? newClientId();
    _mileage = kmController(existing?.mileageKm ?? widget.currentMileageKm);
    _liters = TextEditingController(
      text: existing == null ? '' : litersTextFromVolumeMl(existing.volumeMl),
    );
    _cost = moneyController(existing?.totalCostCents);
    _station = TextEditingController(text: existing?.stationName ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _occurredOn = existing?.occurredOn ?? CivilDate.todayLocal();
    _fullTank = existing?.fullTank ?? true;
    _fuel =
        existing?.fuel ??
        defaultAbastecimentoFuel(
          offered: widget.fuelTypes,
          lastUsed: widget.lastFuel,
        );
    final hasDetails =
        (existing?.stationName?.trim().isNotEmpty ?? false) ||
        (existing?.notes?.trim().isNotEmpty ?? false);
    _showDetails = hasDetails;
    _openedWith = [for (final field in _fields) field.text];
    _dateOpenedWith = _occurredOn;
    _fullTankOpenedWith = _fullTank;
    _fuelOpenedWith = _fuel;
  }

  @override
  void dispose() {
    _mileage.dispose();
    _liters.dispose();
    _cost.dispose();
    _station.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await pickPastDate(context, initial: _occurredOn);
    if (picked == null || !mounted) return;
    setState(() => _occurredOn = picked);
  }

  Future<void> _submit({bool force = false}) async {
    final mileageKm = kmFromField(_mileage.text);
    final volumeMl = volumeMlFromLitersText(_liters.text);
    final totalCostCents = centsFromMoneyField(_cost.text);
    final fuel = _fuel;

    final errors = <String, String>{};
    if (mileageKm == null) {
      errors['mileage_km'] = 'Informe a quilometragem.';
    }
    if (volumeMl == null || volumeMl < 1) {
      errors['volume_ml'] = 'Informe os litros.';
    }
    if (totalCostCents == null) {
      errors['total_cost_cents'] = 'Informe o valor.';
    }
    if (fuel == null || fuel == AbastecimentoFuel.desconhecido) {
      errors['fuel'] = 'Informe o combustível.';
    }
    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors = errors;
        _banner = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _banner = null;
      _offline = false;
      _fieldErrors = {};
    });

    final station = _station.text.trim();
    final notes = _notes.text.trim();
    try {
      if (_editing) {
        await ref
            .read(abastecimentoRepositoryProvider)
            .update(
              widget.existing!.id,
              occurredOn: _occurredOn,
              mileageKm: mileageKm,
              volumeMl: volumeMl,
              totalCostCents: totalCostCents,
              fuel: fuel,
              fullTank: _fullTank,
              stationName: station,
              notes: notes,
              force: force,
            );
      } else {
        await ref
            .read(abastecimentoRepositoryProvider)
            .create(
              vehicleId: widget.vehicleId,
              mileageKm: mileageKm!,
              volumeMl: volumeMl!,
              totalCostCents: totalCostCents!,
              fuel: fuel!,
              occurredOn: _occurredOn,
              fullTank: _fullTank,
              stationName: station.isEmpty ? null : station,
              notes: notes.isEmpty ? null : notes,
              force: force,
              id: _createId,
            );
      }
      invalidateAfterAbastecimentoWrite(ref, widget.vehicleId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showAppSnackBar(
        messenger,
        message: _editing
            ? abastecimentoUpdatedMessage
            : abastecimentoRegisteredMessage,
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
          return;
        }
        _mileage.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _mileage.text.length,
        );
        return;
      }

      final fields = ApiFormErrors.fieldsOf(failure);
      setState(() {
        _fieldErrors = fields;
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
        if (fields.containsKey('station_name') || fields.containsKey('notes')) {
          _showDetails = true;
        }
      });
    }
  }

  /// The fuel of a car that takes only one, stated under the title rather
  /// than offered as a choice of one — the fuel that will be saved, which on
  /// an old fill being edited may not be the one the car takes today. Null
  /// when there is nothing to state.
  String? get _statedFuel {
    final fuel = _fuel;
    if (fuel == null || fuel == AbastecimentoFuel.desconhecido) return null;
    return abastecimentoFuelLabel(fuel);
  }

  @override
  Widget build(BuildContext context) {
    final choosesFuel = widget.fuelTypes.length > 1;
    final fuelError = _fieldErrors['fuel'];

    return AppDiscardGuard(
      listenable: Listenable.merge(_fields),
      isDirty: () => _isDirty,
      busy: _submitting,
      child: AppSheetBody(
        children: [
          AppSheetHeader(
            title: _editing ? 'Editar abastecimento' : 'Abastecer',
            subtitle: choosesFuel ? null : _statedFuel,
          ),
          const SizedBox(height: AppSpacing.s16),
          if (_banner != null) AuthFormBanner(message: _banner!),
          if (choosesFuel) ...[
            AppSegmented<AbastecimentoFuel>(
              value: _fuel ?? AbastecimentoFuel.desconhecido,
              enabled: !_submitting,
              onChanged: (fuel) => setState(() => _fuel = fuel),
              options: [
                for (final fuel in widget.fuelTypes)
                  AppSegmentedOption(
                    value: fuel,
                    label: abastecimentoFuelLabel(fuel),
                  ),
              ],
            ),
            if (fuelError != null) _ErrorLine(fuelError),
            const SizedBox(height: AppSpacing.s16),
          ] else if (fuelError != null) ...[
            _ErrorLine(fuelError),
            const SizedBox(height: AppSpacing.s12),
          ],
          // What the pump shows, in the order it shows it.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppMoneyField(
                  controller: _cost,
                  label: 'Valor total',
                  // A new fill starts on the amount the pump shows.
                  autofocus: !_editing,
                  enabled: !_submitting,
                  errorText: _fieldErrors['total_cost_cents'],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: AppLitersField(
                  controller: _liters,
                  enabled: !_submitting,
                  errorText: _fieldErrors['volume_ml'],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          AppKmField(
            controller: _mileage,
            enabled: !_submitting,
            textInputAction: TextInputAction.done,
            errorText: _fieldErrors['mileage_km'],
            helperText: 'Atual: ${formatKm(widget.currentMileageKm)}',
          ),
          AppSwitchRow(
            title: 'Tanque cheio',
            subtitle: 'Usado para calcular o consumo',
            value: _fullTank,
            onChanged: _submitting
                ? null
                : (value) => setState(() => _fullTank = value),
          ),
          AppDateField(
            value: _occurredOn,
            onPick: _pickDate,
            enabled: !_submitting,
            errorText: _fieldErrors['occurred_on'],
          ),
          if (_showDetails) ...[
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _station,
              enabled: !_submitting,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Posto',
                errorText: _fieldErrors['station_name'],
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _notes,
              enabled: !_submitting,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Observação',
                errorText: _fieldErrors['notes'],
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
          ] else ...[
            const SizedBox(height: AppSpacing.s4),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Adicionar detalhes',
                icon: Icons.add,
                variant: AppButtonVariant.tertiary,
                onPressed: _submitting
                    ? null
                    : () => setState(() => _showDetails = true),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],
          AppButton(
            label: _offline ? 'Tentar de novo' : 'Salvar',
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
            expanded: true,
          ),
        ],
      ),
    );
  }
}

/// A field error that has no field of its own to sit under — the fuel.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s8,
        AppSpacing.s4,
        0,
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
