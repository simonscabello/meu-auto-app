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
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
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
  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  bool get _editing => widget.existing != null;

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
        await ref
            .read(obligationRepositoryProvider)
            .createObligation(
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
    final theme = Theme.of(context);
    final kindLabel = obligationKindLabel(widget.kind);
    final title = _editing ? 'Editar $kindLabel' : 'Registrar $kindLabel';

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s16,
        right: AppSpacing.s16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.s16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s16),
            if (_banner != null) AuthFormBanner(message: _banner!),
            if (!_editing) ...[
              TextField(
                controller: _year,
                enabled: !_submitting,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Ano de referência',
                  errorText: _fieldErrors['reference_year'],
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            AppDateField(
              value: _dueOn,
              onPick: _submitting ? () {} : _pickDueOn,
              label: 'Vencimento',
              emptyLabel: 'Escolher vencimento',
              enabled: !_submitting,
              errorText: _fieldErrors['due_on'],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'A data varia por estado e pelo final da placa.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            AppMoneyField(
              controller: _amount,
              label: 'Valor',
              enabled: !_submitting,
              errorText: _fieldErrors['amount_cents'],
              helperText: 'Opcional',
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _notes,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: 'Observações',
                errorText: _fieldErrors['notes'],
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            AppButton(
              label: _offline ? 'Tentar de novo' : 'Salvar',
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
