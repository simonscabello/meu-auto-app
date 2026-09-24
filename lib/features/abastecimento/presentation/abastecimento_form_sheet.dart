import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
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
import 'package:meu_auto/shared/widgets/app_form_section.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:meu_auto/shared/widgets/app_switch_row.dart';

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

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'Editar abastecimento' : 'Registrar abastecimento';

    return AppDiscardGuard(
      listenable: Listenable.merge(_fields),
      isDirty: () => _isDirty,
      busy: _submitting,
      child: AppSheetBody(
        children: [
          AppSheetHeader(title: title),
          const SizedBox(height: AppSpacing.s16),
          if (_banner != null) AuthFormBanner(message: _banner!),
          AppFormSection(
            title: 'No painel',
            children: [
              AppKmField(
                controller: _mileage,
                enabled: !_submitting,
                errorText: _fieldErrors['mileage_km'],
                helperText: 'Atual: ${formatKm(widget.currentMileageKm)}',
              ),
            ],
          ),
          const AppFormGap(),
          AppFormSection(
            title: 'Na bomba',
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppLitersField(
                      controller: _liters,
                      enabled: !_submitting,
                      errorText: _fieldErrors['volume_ml'],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: AppMoneyField(
                      controller: _cost,
                      label: 'Valor total',
                      enabled: !_submitting,
                      errorText: _fieldErrors['total_cost_cents'],
                    ),
                  ),
                ],
              ),
              _FuelField(
                offered: widget.fuelTypes,
                selected: _fuel,
                enabled: !_submitting,
                errorText: _fieldErrors['fuel'],
                onSelected: (fuel) => setState(() => _fuel = fuel),
              ),
              AppSwitchRow(
                title: 'Tanque cheio',
                subtitle: 'É o que permite calcular o consumo',
                value: _fullTank,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _fullTank = value),
              ),
            ],
          ),
          const AppFormGap(),
          AppFormSection(
            title: 'Quando',
            children: [
              AppDateField(
                value: _occurredOn,
                onPick: _submitting ? () {} : _pickDate,
                enabled: !_submitting,
                errorText: _fieldErrors['occurred_on'],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          if (_showDetails) ...[
            AppFormSection(
              title: 'Detalhes',
              children: [
                TextField(
                  controller: _station,
                  enabled: !_submitting,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Posto (opcional)',
                    errorText: _fieldErrors['station_name'],
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: _notes,
                  enabled: !_submitting,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Observação (opcional)',
                    errorText: _fieldErrors['notes'],
                    counterText: '',
                  ),
                ),
              ],
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Mais detalhes',
                icon: Icons.add,
                variant: AppButtonVariant.tertiary,
                onPressed: _submitting
                    ? null
                    : () => setState(() => _showDetails = true),
              ),
            ),
          const SizedBox(height: AppSpacing.s16),
          AppButton(
            label: _offline
                ? 'Tentar de novo'
                : (_editing
                      ? 'Salvar abastecimento'
                      : 'Registrar abastecimento'),
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
            expanded: true,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Ver histórico',
              variant: AppButtonVariant.tertiary,
              onPressed: _submitting
                  ? null
                  : () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push(AppRoutes.abastecimentos);
                    },
            ),
          ),
        ],
      ),
    );
  }
}

/// Which fuel went in. One chip per fuel the car accepts; a car that takes
/// one fuel sees it stated, not chosen.
class _FuelField extends StatelessWidget {
  const _FuelField({
    required this.offered,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.errorText,
  });

  final List<AbastecimentoFuel> offered;
  final AbastecimentoFuel? selected;
  final bool enabled;
  final ValueChanged<AbastecimentoFuel> onSelected;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.3,
    );

    if (offered.length <= 1) {
      final fuel = offered.isEmpty ? selected : offered.single;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Combustível', style: labelStyle),
            const SizedBox(height: AppSpacing.s4),
            Text(
              abastecimentoFuelLabel(fuel ?? AbastecimentoFuel.desconhecido),
              style: theme.textTheme.bodyLarge,
            ),
            if (errorText != null) ...[
              const SizedBox(height: AppSpacing.s4),
              Text(
                errorText!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Combustível', style: labelStyle),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final fuel in offered)
                ChoiceChip(
                  label: Text(abastecimentoFuelLabel(fuel)),
                  selected: selected == fuel,
                  showCheckmark: false,
                  onSelected: enabled ? (_) => onSelected(fuel) : null,
                ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
