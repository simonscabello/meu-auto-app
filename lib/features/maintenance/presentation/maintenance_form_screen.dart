import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';
import 'package:meu_auto/features/maintenance/presentation/item_picker_sheet.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_rollback_dialog.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_discard_guard.dart';
import 'package:meu_auto/shared/widgets/app_folded_section.dart';
import 'package:meu_auto/shared/widgets/app_form_section.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:meu_auto/shared/widgets/app_switch_row.dart';

class MaintenanceFormScreen extends ConsumerStatefulWidget {
  const MaintenanceFormScreen({
    super.key,
    required this.vehicleId,
    required this.currentMileageKm,
    this.preselectedItem,
    this.preselectedItemId,
    this.newId,
  });

  final String vehicleId;
  final int currentMileageKm;
  final MaintenanceItem? preselectedItem;
  final String? preselectedItemId;
  final String Function()? newId;

  @override
  ConsumerState<MaintenanceFormScreen> createState() =>
      _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends ConsumerState<MaintenanceFormScreen> {
  late final String _createId;
  late final TextEditingController _mileage;
  final _workshop = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  final _lines = <String, _LineControllers>{};

  late CivilDate _occurredOn;
  late final CivilDate _initialOccurredOn;
  late final String _initialMileage;
  bool _declared = false;
  bool _preselectedApplied = false;
  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};
  List<MaintenanceItem> _items = [];

  @override
  void initState() {
    super.initState();
    _createId = widget.newId?.call() ?? newClientId();
    _occurredOn = CivilDate.todayLocal();
    _initialOccurredOn = _occurredOn;
    _mileage = kmController(widget.currentMileageKm);
    _initialMileage = _mileage.text;
    final preselected = widget.preselectedItem;
    if (preselected != null) {
      _items = [preselected];
      _lines[preselected.id] = _LineControllers();
      _preselectedApplied = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryPreselect());
  }

  void _tryPreselect() {
    final items = ref.read(maintenanceItemsProvider).valueOrNull;
    if (items != null) _applyPreselectedId(items);
  }

  @override
  void dispose() {
    _mileage.dispose();
    _workshop.dispose();
    _cost.dispose();
    _notes.dispose();
    for (final line in _lines.values) {
      line.dispose();
    }
    super.dispose();
  }

  bool get _isDirty {
    if (_declared) return true;
    if (_occurredOn != _initialOccurredOn) return true;
    if (_mileage.text.trim() != _initialMileage) return true;
    if (_workshop.text.trim().isNotEmpty) return true;
    if (_cost.text.trim().isNotEmpty) return true;
    if (_notes.text.trim().isNotEmpty) return true;
    final initialId = widget.preselectedItem?.id;
    if (initialId == null) {
      if (_items.isNotEmpty) return true;
    } else if (_items.length != 1 || _items.first.id != initialId) {
      return true;
    }
    for (final line in _lines.values) {
      if (line.isDirty) return true;
    }
    return false;
  }

  void _applyPreselectedId(List<MaintenanceItem> catalogue) {
    final id = widget.preselectedItemId;
    if (id == null || _preselectedApplied) return;
    for (final item in catalogue) {
      if (item.id != id) continue;
      _preselectedApplied = true;
      if (_items.any((existing) => existing.id == id)) return;
      setState(() => _setItems([..._items, item]));
      return;
    }
  }

  void _setItems(List<MaintenanceItem> next) {
    final nextIds = {for (final item in next) item.id};
    for (final entry in [..._lines.entries]) {
      if (nextIds.contains(entry.key)) continue;
      entry.value.dispose();
      _lines.remove(entry.key);
    }
    for (final item in next) {
      _lines.putIfAbsent(item.id, _LineControllers.new);
    }
    _items = next;
  }

  Future<void> _openPicker() async {
    final selected = await ItemPickerSheet.show(
      context,
      selected: _items,
      hiddenItemIds: notApplicableItemIds(
        ref.read(maintenancePlansWithHiddenProvider(widget.vehicleId)),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _setItems(selected));
  }

  Future<void> _submit({bool correction = false}) async {
    final mileage = kmFromField(_mileage.text);
    if (mileage == null) {
      setState(() {
        _fieldErrors = {'mileage_km': 'Informe a quilometragem.'};
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

    final typed = _draft(mileage);
    final draft = correction ? typed.asCorrection() : typed;
    try {
      final created = await ref
          .read(maintenanceRecordRepositoryProvider)
          .create(widget.vehicleId, draft);

      invalidateAfterMaintenanceWrite(ref, widget.vehicleId);
      unawaited(ref.read(vehiclesProvider.notifier).reload());

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pushReplacement(AppRoutes.maintenanceRecord(created.id));
      showAppSnackBar(messenger, message: 'Manutenção registrada.');
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
          await _submit(correction: true);
        }
        return;
      }

      setState(() {
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
      });
    }
  }

  MaintenanceRecordDraft _draft(int mileage) {
    return MaintenanceRecordDraft(
      id: _createId,
      occurredOn: _occurredOn,
      mileageKm: mileage,
      kind: _declared
          ? MaintenanceRecordKind.declared
          : MaintenanceRecordKind.performed,
      workshopName: _workshop.text,
      totalCostCents: _moneyOf(_cost),
      notes: _notes.text,
      items: [for (final item in _items) _lineOf(item)],
    );
  }

  MaintenanceRecordLineDraft _lineOf(MaintenanceItem item) {
    final line = _lines[item.id];
    return MaintenanceRecordLineDraft(
      item: item,
      description: line?.description.text,
      partBrand: line?.partBrand.text,
      costCents: line == null ? null : _moneyOf(line.cost),
      warrantyMonths: _positiveInt(line?.warrantyMonths.text ?? ''),
      warrantyKm: _positiveInt(line?.warrantyKm.text ?? ''),
    );
  }

  Money? _moneyOf(TextEditingController controller) {
    final cents = centsFromMoneyField(controller.text);
    if (cents == null) return null;
    return Money.fromCents(cents);
  }

  /// Reads the digits, so the masked kilometre field and the plain month
  /// field are both understood by the same helper.
  int? _positiveInt(String raw) {
    final value = kmFromField(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _pickDate() async {
    final picked = await pickPastDate(context, initial: _occurredOn);
    if (picked == null || !mounted) return;
    setState(() {
      _occurredOn = picked;
      // Today's mileage is the right guess for a service done today and the
      // wrong one for anything earlier. A past date with the prefilled value
      // untouched clears it, so the field asks.
      if (picked != _initialOccurredOn && _mileage.text == _initialMileage) {
        _mileage.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Warmed here so the picker can leave out what the car does not have.
    ref.watch(maintenancePlansWithHiddenProvider(widget.vehicleId));
    ref.listen(maintenanceItemsProvider, (previous, next) {
      final items = next.valueOrNull;
      if (items != null) _applyPreselectedId(items);
    });

    final theme = Theme.of(context);
    final canSave = _items.isNotEmpty;
    final detailsHaveError = _fieldErrors.keys.any(
      (key) => key.startsWith('items['),
    );

    return AppDiscardGuard(
      listenable: Listenable.merge([
        _mileage,
        _workshop,
        _cost,
        _notes,
        for (final line in _lines.values) ...line.all,
      ]),
      isDirty: () => _isDirty,
      busy: _submitting,
      title: 'Descartar este registro?',
      message: 'O que você preencheu será perdido.',
      child: AppScaffold(
        title: 'Registrar manutenção',
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: AppSpacing.screen,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (_banner != null) AuthFormBanner(message: _banner!),
                  AppFormSection(
                    title: 'O que foi feito',
                    children: [
                      AppGroup(
                        children: [
                          for (var i = 0; i < _items.length; i++) _itemRow(i),
                          AppListRow(
                            icon: Icons.add,
                            iconTone: AppIconWellTone.accent,
                            title: _items.isEmpty
                                ? 'Adicionar item'
                                : 'Adicionar outro item',
                            onTap: _submitting ? null : _openPicker,
                            showChevron: true,
                          ),
                        ],
                      ),
                      if (_fieldErrors['items'] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s4,
                          ),
                          child: Text(
                            _fieldErrors['items']!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const AppFormGap(),
                  AppFormSection(
                    title: 'Quando',
                    children: [
                      AppDateField(
                        value: _occurredOn,
                        onPick: _pickDate,
                        enabled: !_submitting,
                        errorText: _fieldErrors['occurred_on'],
                      ),
                      AppKmField(
                        controller: _mileage,
                        enabled: !_submitting,
                        label: _occurredOn == _initialOccurredOn
                            ? 'Quilometragem'
                            : 'Quilometragem no dia do serviço',
                        helperText:
                            'Hoje: ${formatKm(widget.currentMileageKm)}',
                        errorText: _fieldErrors['mileage_km'],
                      ),
                      AppSwitchRow(
                        title: 'Não tenho o comprovante',
                        subtitle:
                            'Para um serviço informado de memória — feito '
                            'antes de você usar o app, por exemplo',
                        value: _declared,
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _declared = value),
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
                        decoration: InputDecoration(
                          labelText: 'Oficina',
                          counterText: '',
                          errorText: _fieldErrors['workshop_name'],
                        ),
                      ),
                      AppMoneyField(
                        controller: _cost,
                        label: 'Valor total',
                        enabled: !_submitting,
                        errorText: _fieldErrors['total_cost_cents'],
                      ),
                      TextField(
                        controller: _notes,
                        enabled: !_submitting,
                        maxLength: 500,
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Observação',
                          counterText: '',
                          errorText: _fieldErrors['notes'],
                        ),
                      ),
                    ],
                  ),
                  if (_items.isNotEmpty) ...[
                    const AppFormGap(),
                    AppFoldedSection(
                      title: 'Detalhes por item',
                      subtitle:
                          'Garantia, marca e valor de cada serviço — opcional',
                      initiallyOpen: detailsHaveError,
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          _ItemDetails(
                            item: _items[i],
                            controllers: _lines[_items[i].id]!,
                            enabled: !_submitting,
                            fieldErrors: _fieldErrors,
                            index: i,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            AppFormFooter(
              // A hint, not an error: nothing has gone wrong on a form that
              // just opened.
              hint: canSave ? null : MaintenanceRecordDraft.noItemsReason,
              child: AppButton(
                label: _offline ? 'Tentar de novo' : 'Salvar',
                loading: _submitting,
                onPressed: canSave ? _submit : null,
                expanded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(int index) {
    final item = _items[index];
    final id = item.id;
    return AppListRow(
      key: ValueKey(id),
      icon: maintenanceIconFor(item.slug),
      title: item.name,
      subtitle: _rowError(index),
      accent: _rowError(index) == null
          ? null
          : Theme.of(context).colorScheme.error,
      trailing: AppIconButton(
        label: 'Remover ${item.name}',
        icon: Icons.close,
        onPressed: _submitting
            ? null
            : () => setState(
                () => _setItems([
                  for (final current in _items)
                    if (current.id != id) current,
                ]),
              ),
      ),
    );
  }

  String? _rowError(int index) {
    const names = [
      'description',
      'part_brand',
      'cost_cents',
      'warranty_months',
      'warranty_km',
      'maintenance_item_id',
    ];
    for (final name in names) {
      final error = itemFieldError(_fieldErrors, index, name);
      if (error != null) return error;
    }
    return null;
  }
}

class _ItemDetails extends StatelessWidget {
  const _ItemDetails({
    required this.item,
    required this.controllers,
    required this.enabled,
    required this.fieldErrors,
    required this.index,
  });

  final MaintenanceItem item;
  final _LineControllers controllers;
  final bool enabled;
  final Map<String, String> fieldErrors;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: AppFormSection(
        title: item.name,
        children: [
          TextField(
            controller: controllers.description,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Descrição',
              errorText: itemFieldError(fieldErrors, index, 'description'),
            ),
          ),
          TextField(
            controller: controllers.partBrand,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Marca da peça',
              errorText: itemFieldError(fieldErrors, index, 'part_brand'),
            ),
          ),
          AppMoneyField(
            controller: controllers.cost,
            label: 'Valor deste item',
            enabled: enabled,
            errorText: itemFieldError(fieldErrors, index, 'cost_cents'),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: controllers.warrantyMonths,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Garantia',
                    suffixText: 'meses',
                    errorText: itemFieldError(
                      fieldErrors,
                      index,
                      'warranty_months',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: AppKmField(
                  controller: controllers.warrantyKm,
                  label: 'Garantia',
                  enabled: enabled,
                  textInputAction: TextInputAction.done,
                  errorText: itemFieldError(fieldErrors, index, 'warranty_km'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineControllers {
  final description = TextEditingController();
  final partBrand = TextEditingController();
  final cost = TextEditingController();
  final warrantyMonths = TextEditingController();
  final warrantyKm = TextEditingController();

  List<TextEditingController> get all => [
    description,
    partBrand,
    cost,
    warrantyMonths,
    warrantyKm,
  ];

  bool get isDirty =>
      description.text.trim().isNotEmpty ||
      partBrand.text.trim().isNotEmpty ||
      cost.text.trim().isNotEmpty ||
      warrantyMonths.text.trim().isNotEmpty ||
      warrantyKm.text.trim().isNotEmpty;

  void dispose() {
    description.dispose();
    partBrand.dispose();
    cost.dispose();
    warrantyMonths.dispose();
    warrantyKm.dispose();
  }
}
