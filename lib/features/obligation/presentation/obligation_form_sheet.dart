import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/domain/obligation_copy.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_discard_guard.dart';
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
  late bool _showNotes;
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
    _showNotes = _notes.text.trim().isNotEmpty;
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
        if (_fieldErrors.containsKey('notes')) _showNotes = true;
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
    final theme = Theme.of(context);
    final kind = obligationKindInSentence(widget.kind);
    final existing = widget.existing;
    final title = existing == null
        ? 'Registrar $kind'
        : 'Editar ${obligationTitle(existing)}';

    return AppDiscardGuard(
      listenable: Listenable.merge(_fields),
      isDirty: () => _isDirty,
      busy: _submitting,
      child: AppSheetBody(
        children: [
          AppSheetHeader(title: title),
          const SizedBox(height: AppSpacing.s16),
          if (_banner != null) AuthFormBanner(message: _banner!),
          // The year is what the document is called — "IPVA 2026" — so it
          // is asked once, on the way in, and never edited afterwards.
          if (!_editing) ...[
            TextField(
              controller: _year,
              enabled: !_submitting,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
              decoration: InputDecoration(
                labelText: 'Ano',
                errorText: _fieldErrors['reference_year'],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],
          AppDateField(
            value: _dueOn,
            onPick: _submitting ? () {} : _pickDueOn,
            label: 'Vencimento',
            emptyLabel: 'Escolher data',
            enabled: !_submitting,
            errorText: _fieldErrors['due_on'],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              0,
            ),
            child: Text(
              'Muda com o estado e o final da placa.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          AppMoneyField(
            controller: _amount,
            label: 'Valor (opcional)',
            enabled: !_submitting,
            errorText: _fieldErrors['amount_cents'],
            textInputAction: _showNotes
                ? TextInputAction.next
                : TextInputAction.done,
          ),
          if (_showNotes) ...[
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _notes,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Observação',
                errorText: _fieldErrors['notes'],
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
            label: _offline
                ? 'Tentar de novo'
                : (_editing ? 'Salvar' : 'Registrar $kind'),
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
            expanded: true,
          ),
        ],
      ),
    );
  }
}
