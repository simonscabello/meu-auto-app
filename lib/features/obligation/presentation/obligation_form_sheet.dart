import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/domain/obligation_copy.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_discard_guard.dart';
import 'package:meu_auto/shared/widgets/app_form_section.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class ObligationFormSheet extends ConsumerStatefulWidget {
  const ObligationFormSheet({
    super.key,
    required this.vehicleId,
    required this.kind,
    this.existing,
  });

  final String vehicleId;
  final ObligationKind kind;
  final Obligation? existing;

  static Future<void> show(
    BuildContext context, {
    required String vehicleId,
    required ObligationKind kind,
    Obligation? existing,
  }) {
    return showAppSheet<void>(
      context,
      isForm: true,
      builder: (sheetContext) => ObligationFormSheet(
        vehicleId: vehicleId,
        kind: kind,
        existing: existing,
      ),
    );
  }

  @override
  ConsumerState<ObligationFormSheet> createState() =>
      _ObligationFormSheetState();
}

class _ObligationFormSheetState extends ConsumerState<ObligationFormSheet> {
  late final TextEditingController _year;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  CivilDate? _dueOn;

  /// Kept across retries of a create, for the year it was taken for. A retry
  /// after a timeout then gets its own row back instead of "já existe um IPVA
  /// deste ano"; a different year is a different request and takes a new id.
  String? _createId;
  int? _createIdYear;
  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  bool get _editing => widget.existing != null;

  late final List<String> _openedWith;
  CivilDate? _dueOpenedWith;

  List<TextEditingController> get _fields => [_year, _amount, _notes];

  bool get _isDirty {
    if (_dueOn != _dueOpenedWith) return true;
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
    _year = TextEditingController(
      text: '${existing?.referenceYear ?? CivilDate.todayLocal().year}',
    );
    _amount = moneyController(existing?.amountCents);
    _notes = TextEditingController(text: existing?.notes ?? '');
    _dueOn = existing?.dueOn;
    _openedWith = [for (final field in _fields) field.text];
    _dueOpenedWith = _dueOn;
  }

  @override
  void dispose() {
    _year.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDueOn() async {
    final picked = await pickCivilDate(context, initial: _dueOn);
    if (picked == null || !mounted) return;
    setState(() => _dueOn = picked);
  }

  Future<void> _submit() async {
    final year = int.tryParse(_year.text.trim());
    if (!_editing && year == null) {
      setState(() {
        _fieldErrors = {'reference_year': 'Informe o ano.'};
        _banner = null;
      });
      return;
    }
    if (_dueOn == null) {
      setState(() {
        _fieldErrors = {'due_on': 'Informe o vencimento.'};
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

    final notes = _notes.text.trim();
    try {
      if (_editing) {
        await ref
            .read(obligationRepositoryProvider)
            .updateObligation(
              widget.existing!.id,
              dueOn: _dueOn,
              amountCents: centsFromMoneyField(_amount.text),
              notes: notes,
            );
      } else {
        final repository = ref.read(obligationRepositoryProvider);
        if (_createId == null || _createIdYear != year) {
          _createId = repository.nextId();
          _createIdYear = year;
        }
        await repository.createObligation(
          id: _createId,
          vehicleId: widget.vehicleId,
          kind: widget.kind,
          referenceYear: year!,
          dueOn: _dueOn!,
          amountCents: centsFromMoneyField(_amount.text),
          notes: notes.isEmpty ? null : notes,
        );
      }
      invalidateAfterObligationWrite(ref, widget.vehicleId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showAppSnackBar(
        messenger,
        message: _editing
            ? obligationUpdatedMessage(widget.kind)
            : obligationRegisteredMessage(widget.kind),
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
        if (failure.code == ApiErrorCode.conflict && year != null) {
          _banner = obligationConflictMessage(kind: widget.kind, year: year);
          return;
        }
        _banner = ApiFormErrors.bannerOf(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kindLabel = obligationKindLabel(widget.kind);
    final title = _editing ? 'Editar $kindLabel' : 'Registrar $kindLabel';

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
            title: 'Prazo',
            children: [
              if (!_editing)
                TextField(
                  controller: _year,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Ano de referência',
                    errorText: _fieldErrors['reference_year'],
                  ),
                ),
              AppDateField(
                value: _dueOn,
                onPick: _submitting ? () {} : _pickDueOn,
                label: 'Vencimento',
                emptyLabel: 'Escolher vencimento',
                enabled: !_submitting,
                errorText: _fieldErrors['due_on'],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                child: Text(
                  'A data varia por estado e pelo final da placa.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const AppFormGap(),
          AppFormSection(
            title: 'Valor e observações',
            children: [
              AppMoneyField(
                controller: _amount,
                label: 'Valor (opcional)',
                enabled: !_submitting,
                errorText: _fieldErrors['amount_cents'],
              ),
              TextField(
                controller: _notes,
                enabled: !_submitting,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Observações (opcional)',
                  errorText: _fieldErrors['notes'],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          AppButton(
            label: _offline
                ? 'Tentar de novo'
                : (_editing ? 'Salvar $kindLabel' : 'Registrar $kindLabel'),
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
            expanded: true,
          ),
        ],
      ),
    );
  }
}
