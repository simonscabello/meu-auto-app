import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class ObligationPaymentSheet extends ConsumerStatefulWidget {
  const ObligationPaymentSheet({super.key, required this.obligation});

  final Obligation obligation;

  static Future<void> show(
    BuildContext context, {
    required Obligation obligation,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => ObligationPaymentSheet(obligation: obligation),
    );
  }

  @override
  ConsumerState<ObligationPaymentSheet> createState() =>
      _ObligationPaymentSheetState();
}

class _ObligationPaymentSheetState
    extends ConsumerState<ObligationPaymentSheet> {
  late CivilDate _paidOn;
  late final TextEditingController _amount;
  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _paidOn = CivilDate.todayLocal();
    _amount = moneyController(widget.obligation.amountCents);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await pickPastDate(context, initial: _paidOn);
    if (picked == null || !mounted) return;
    setState(() => _paidOn = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _banner = null;
      _offline = false;
      _fieldErrors = {};
    });

    try {
      await ref
          .read(obligationRepositoryProvider)
          .updateObligation(
            widget.obligation.id,
            paidOn: _paidOn,
            paidAmountCents: centsFromMoneyField(_amount.text),
          );
      invalidateAfterObligationWrite(ref, widget.obligation.vehicleId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showAppSnackBar(messenger, message: 'Pagamento registrado.');
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text('Marcar como pago', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s16),
            if (_banner != null) AuthFormBanner(message: _banner!),
            AppDateField(
              value: _paidOn,
              onPick: _submitting ? () {} : _pickDate,
              label: 'Data do pagamento',
              enabled: !_submitting,
              errorText: _fieldErrors['paid_on'],
            ),
            const SizedBox(height: AppSpacing.s12),
            AppMoneyField(
              controller: _amount,
              label: 'Valor pago',
              enabled: !_submitting,
              errorText: _fieldErrors['paid_amount_cents'],
            ),
            const SizedBox(height: AppSpacing.s16),
            AppButton(
              label: _offline ? 'Tentar de novo' : 'Registrar pagamento',
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
