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
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

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
    _initialMileage = widget.currentMileageKm.toString();
    _mileage = TextEditingController(text: _initialMileage)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: _initialMileage.length,
      );
    final preselected = widget.preselectedItem;
    if (preselected != null) {
      _items = [preselected];
      _lines[preselected.id] = _LineControllers();
      _preselectedApplied = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryPreselect());
  }

  void _tryPreselect() {
    final items = ref.read(maintenanceItemsProvider).value;
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
    final selected = await ItemPickerSheet.show(context, selected: _items);
    if (selected == null || !mounted) return;
    setState(() => _setItems(selected));
  }

  Future<void> _submit() async {
    final mileage = int.tryParse(_mileage.text.trim());
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

    final draft = _draft(mileage);
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
          await _submit();
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
    final cents = centsFromDigitField(controller.text);
    if (cents == null) return null;
    return Money.fromCents(cents);
  }

  int? _positiveInt(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _pickDate() async {
    final picked = await pickPastDate(context, initial: _occurredOn);
    if (picked == null || !mounted) return;
    setState(() => _occurredOn = picked);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar este registro?'),
        content: const Text('O que você preencheu será perdido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(maintenanceItemsProvider, (previous, next) {
      final items = next.value;
      if (items != null) _applyPreselectedId(items);
    });

    final canSave = _items.isNotEmpty;
    final isToday = _occurredOn == CivilDate.todayLocal();
    final totalHint = _moneyOf(_cost);

    return PopScope(
      canPop: !_submitting && !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _submitting) return;
        final discard = await _confirmDiscard();
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AppScaffold(
        title: 'Registrar manutenção',
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.s16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (_banner != null) AuthFormBanner(message: _banner!),
                  const AppSectionHeader(title: 'O que foi feito'),
                  const SizedBox(height: AppSpacing.s8),
                  for (var i = 0; i < _items.length; i++) ...[
                    _itemCard(i),
                    const SizedBox(height: AppSpacing.s8),
                  ],
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _openPicker,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      _items.isEmpty
                          ? 'Adicionar item'
                          : 'Adicionar outro item',
                    ),
                  ),
                  if (_fieldErrors['items'] != null) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      _fieldErrors['items']!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s24),
                  const AppSectionHeader(title: 'Quando'),
                  const SizedBox(height: AppSpacing.s8),
                  Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 20),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          isToday ? 'Hoje' : formatCivilDateLong(_occurredOn),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: _submitting ? null : _pickDate,
                        child: const Text('Mudar data'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  TextField(
                    controller: _mileage,
                    enabled: !_submitting,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Quilometragem',
                      suffixText: 'km',
                      helperText: 'Atual: ${formatKm(widget.currentMileageKm)}',
                      errorText: _fieldErrors['mileage_km'],
                      errorMaxLines: 3,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Não tenho o comprovante'),
                    subtitle: const Text(
                      'Use quando estiver informando de memória, por exemplo '
                      'um serviço feito antes de você começar a usar o app.',
                    ),
                    value: _declared,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _declared = value),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  const AppSectionHeader(title: 'Onde e quanto'),
                  const SizedBox(height: AppSpacing.s8),
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
                      errorMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  TextField(
                    controller: _cost,
                    enabled: !_submitting,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Valor total',
                      helperText: totalHint == null
                          ? 'Digite em centavos: 42000 vira R\$ 420,00'
                          : totalHint.format(),
                      errorText: _fieldErrors['total_cost_cents'],
                      errorMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
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
                      errorMaxLines: 3,
                    ),
                  ),
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s16),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      initiallyExpanded: false,
                      title: const Text('Detalhes por item'),
                      subtitle: const Text(
                        'Garantia, marca e valor de cada serviço — opcional',
                      ),
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
                  const SizedBox(height: AppSpacing.s16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                0,
                AppSpacing.s16,
                AppSpacing.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!canSave) ...[
                    Text(
                      MaintenanceRecordDraft.noItemsReason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                  ],
                  AppButton(
                    label: _offline ? 'Tentar de novo' : 'Salvar',
                    loading: _submitting,
                    onPressed: canSave ? _submit : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(int index) {
    final item = _items[index];
    final id = item.id;
    return _SelectedItemCard(
      item: item,
      errorText: _cardError(index),
      onRemove: _submitting
          ? null
          : () => setState(
              () => _setItems([
                for (final current in _items)
                  if (current.id != id) current,
              ]),
            ),
    );
  }

  String? _cardError(int index) {
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

class _SelectedItemCard extends StatelessWidget {
  const _SelectedItemCard({
    required this.item,
    required this.onRemove,
    this.errorText,
  });

  final MaintenanceItem item;
  final VoidCallback? onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s4,
        AppSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                maintenanceIconFor(item.slug),
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(item.name, style: theme.textTheme.titleSmall),
              ),
              AppIconButton(
                label: 'Remover',
                icon: Icons.close,
                onPressed: onRemove,
              ),
            ],
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.s8,
                bottom: AppSpacing.s8,
              ),
              child: Text(
                errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.s8),
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
          const SizedBox(height: AppSpacing.s8),
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
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: controllers.cost,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: InputDecoration(
              labelText: 'Valor da linha',
              helperText: 'Em centavos',
              errorText: itemFieldError(fieldErrors, index, 'cost_cents'),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: controllers.warrantyMonths,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: 'Garantia em meses',
              errorText: itemFieldError(fieldErrors, index, 'warranty_months'),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: controllers.warrantyKm,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: InputDecoration(
              labelText: 'Garantia em km',
              errorText: itemFieldError(fieldErrors, index, 'warranty_km'),
            ),
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
