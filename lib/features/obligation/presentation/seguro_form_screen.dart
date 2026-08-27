import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class SeguroEditScreen extends ConsumerWidget {
  const SeguroEditScreen({super.key, required this.seguroId});

  final String seguroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seguro = ref.watch(seguroProvider(seguroId));
    return seguro.when(
      loading: () => const AppScaffold(
        title: 'Editar seguro',
        body: Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(count: 6, itemHeight: 56),
        ),
      ),
      error: (error, _) => AppScaffold(
        title: 'Editar seguro',
        body: AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(seguroProvider(seguroId)),
        ),
      ),
      data: (current) =>
          SeguroFormScreen(vehicleId: current.vehicleId, existing: current),
    );
  }
}

class SeguroFormScreen extends ConsumerStatefulWidget {
  const SeguroFormScreen({super.key, required this.vehicleId, this.existing});

  final String vehicleId;
  final Seguro? existing;

  @override
  ConsumerState<SeguroFormScreen> createState() => _SeguroFormScreenState();
}

class _SeguroFormScreenState extends ConsumerState<SeguroFormScreen> {
  late final TextEditingController _insurer;
  late final TextEditingController _policy;
  late final TextEditingController _premium;
  late final TextEditingController _emergency;
  late final TextEditingController _brokerName;
  late final TextEditingController _brokerPhone;
  late final TextEditingController _notes;
  CivilDate? _startsOn;
  CivilDate? _endsOn;
  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _insurer = TextEditingController(text: existing?.insurerName ?? '');
    _policy = TextEditingController(text: existing?.policyNumber ?? '');
    _premium = moneyController(existing?.premiumCents);
    _emergency = TextEditingController(text: existing?.emergencyPhone ?? '');
    _brokerName = TextEditingController(text: existing?.brokerName ?? '');
    _brokerPhone = TextEditingController(text: existing?.brokerPhone ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _startsOn = existing?.startsOn ?? CivilDate.todayLocal();
    _endsOn = existing?.endsOn;
  }

  @override
  void dispose() {
    _insurer.dispose();
    _policy.dispose();
    _premium.dispose();
    _emergency.dispose();
    _brokerName.dispose();
    _brokerPhone.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final existing = widget.existing;
    if (existing == null) {
      return _insurer.text.trim().isNotEmpty ||
          _policy.text.trim().isNotEmpty ||
          _premium.text.trim().isNotEmpty ||
          _emergency.text.trim().isNotEmpty ||
          _brokerName.text.trim().isNotEmpty ||
          _brokerPhone.text.trim().isNotEmpty ||
          _notes.text.trim().isNotEmpty ||
          _endsOn != null;
    }
    return _insurer.text.trim() != existing.insurerName ||
        _policy.text.trim() != (existing.policyNumber ?? '') ||
        _emergency.text.trim() != (existing.emergencyPhone ?? '') ||
        _brokerName.text.trim() != (existing.brokerName ?? '') ||
        _brokerPhone.text.trim() != (existing.brokerPhone ?? '') ||
        _notes.text.trim() != (existing.notes ?? '') ||
        _startsOn != existing.startsOn ||
        _endsOn != existing.endsOn ||
        centsFromMoneyField(_premium.text) != existing.premiumCents?.cents;
  }

  Future<void> _pickStartsOn() async {
    final picked = await pickCivilDate(context, initial: _startsOn);
    if (picked == null || !mounted) return;
    setState(() => _startsOn = picked);
  }

  Future<void> _pickEndsOn() async {
    final picked = await pickCivilDate(context, initial: _endsOn ?? _startsOn);
    if (picked == null || !mounted) return;
    setState(() => _endsOn = picked);
  }

  Future<bool> _confirmDiscard() {
    return confirmAction(
      context,
      title: 'Descartar este registro?',
      message: 'O que você preencheu será perdido.',
      cancelLabel: 'Continuar editando',
      confirmLabel: 'Descartar',
      destructive: true,
    );
  }

  Future<void> _submit() async {
    final insurer = _insurer.text.trim();
    if (insurer.isEmpty) {
      setState(() {
        _fieldErrors = {'insurer_name': 'Informe a seguradora.'};
        _banner = null;
      });
      return;
    }
    if (_startsOn == null) {
      setState(() {
        _fieldErrors = {'starts_on': 'Informe o início da vigência.'};
        _banner = null;
      });
      return;
    }
    if (_endsOn == null) {
      setState(() {
        _fieldErrors = {'ends_on': 'Informe o fim da vigência.'};
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
    final policy = _policy.text.trim();
    final emergency = _emergency.text.trim();
    final brokerName = _brokerName.text.trim();
    final brokerPhone = _brokerPhone.text.trim();

    try {
      if (_editing) {
        await ref
            .read(obligationRepositoryProvider)
            .updateSeguro(
              widget.existing!.id,
              insurerName: insurer,
              policyNumber: policy,
              startsOn: _startsOn,
              endsOn: _endsOn,
              premiumCents: centsFromMoneyField(_premium.text),
              emergencyPhone: emergency,
              brokerName: brokerName,
              brokerPhone: brokerPhone,
              notes: notes,
            );
      } else {
        await ref
            .read(obligationRepositoryProvider)
            .createSeguro(
              vehicleId: widget.vehicleId,
              insurerName: insurer,
              startsOn: _startsOn!,
              endsOn: _endsOn!,
              policyNumber: policy.isEmpty ? null : policy,
              premiumCents: centsFromMoneyField(_premium.text),
              emergencyPhone: emergency.isEmpty ? null : emergency,
              brokerName: brokerName.isEmpty ? null : brokerName,
              brokerPhone: brokerPhone.isEmpty ? null : brokerPhone,
              notes: notes.isEmpty ? null : notes,
            );
      }
      invalidateAfterSeguroWrite(ref, widget.vehicleId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      showAppSnackBar(
        messenger,
        message: _editing ? 'Seguro atualizado.' : 'Seguro registrado.',
      );
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
        title: _editing ? 'Editar seguro' : 'Registrar seguro',
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            if (_banner != null) AuthFormBanner(message: _banner!),
            TextField(
              controller: _insurer,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Seguradora',
                errorText: _fieldErrors['insurer_name'],
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            AppDateField(
              value: _startsOn,
              onPick: _submitting ? () {} : _pickStartsOn,
              label: 'Início da vigência',
              emptyLabel: 'Escolher data',
              enabled: !_submitting,
              errorText: _fieldErrors['starts_on'],
            ),
            const SizedBox(height: AppSpacing.s12),
            AppDateField(
              value: _endsOn,
              onPick: _submitting ? () {} : _pickEndsOn,
              label: 'Fim da vigência',
              emptyLabel: 'Escolher data',
              enabled: !_submitting,
              errorText: _fieldErrors['ends_on'],
            ),
            const SizedBox(height: AppSpacing.s12),
            AppMoneyField(
              controller: _premium,
              label: 'Prêmio',
              enabled: !_submitting,
              errorText: _fieldErrors['premium_cents'],
              helperText: 'Opcional',
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _emergency,
              enabled: !_submitting,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Telefone de emergência',
                errorText: _fieldErrors['emergency_phone'],
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _policy,
              enabled: !_submitting,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Número da apólice',
                errorText: _fieldErrors['policy_number'],
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _brokerName,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Corretor',
                errorText: _fieldErrors['broker_name'],
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _brokerPhone,
              enabled: !_submitting,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Telefone do corretor',
                errorText: _fieldErrors['broker_phone'],
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _notes,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Observações',
                errorText: _fieldErrors['notes'],
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
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
