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
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_discard_guard.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_form_section.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
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
          padding: AppSpacing.screen,
          child: AppSkeletonList(count: 5, itemHeight: 56),
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

  /// Kept across retries of a create, so a timeout does not become two
  /// policies — and a premium counted twice in the costs.
  String? _createId;
  CivilDate? _startsOn;
  CivilDate? _endsOn;
  late bool _showDetails;
  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  static const _detailFieldKeys = {
    'emergency_phone',
    'policy_number',
    'broker_name',
    'broker_phone',
    'notes',
  };

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
    _showDetails =
        _policy.text.trim().isNotEmpty ||
        _emergency.text.trim().isNotEmpty ||
        _brokerName.text.trim().isNotEmpty ||
        _brokerPhone.text.trim().isNotEmpty ||
        _notes.text.trim().isNotEmpty;
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
        final repository = ref.read(obligationRepositoryProvider);
        _createId ??= repository.nextId();
        await repository.createSeguro(
          id: _createId,
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
      final fields = ApiFormErrors.fieldsOf(failure);
      setState(() {
        _submitting = false;
        _fieldErrors = fields;
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
        if (fields.keys.any(_detailFieldKeys.contains)) {
          _showDetails = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDiscardGuard(
      listenable: Listenable.merge([
        _insurer,
        _policy,
        _premium,
        _emergency,
        _brokerName,
        _brokerPhone,
        _notes,
      ]),
      isDirty: () => _isDirty,
      busy: _submitting,
      title: 'Descartar este registro?',
      message: 'O que você preencheu será perdido.',
      child: AppScaffold(
        title: _editing ? 'Editar seguro' : 'Registrar seguro',
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
                    title: 'Apólice',
                    children: [
                      TextField(
                        controller: _insurer,
                        enabled: !_submitting,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Seguradora',
                          errorText: _fieldErrors['insurer_name'],
                        ),
                      ),
                      AppMoneyField(
                        controller: _premium,
                        label: 'Prêmio (opcional)',
                        enabled: !_submitting,
                        errorText: _fieldErrors['premium_cents'],
                      ),
                    ],
                  ),
                  const AppFormGap(),
                  AppFormSection(
                    title: 'Vigência',
                    children: [
                      AppDateField(
                        value: _startsOn,
                        onPick: _submitting ? () {} : _pickStartsOn,
                        label: 'Início',
                        emptyLabel: 'Escolher data',
                        enabled: !_submitting,
                        errorText: _fieldErrors['starts_on'],
                      ),
                      AppDateField(
                        value: _endsOn,
                        onPick: _submitting ? () {} : _pickEndsOn,
                        label: 'Fim',
                        emptyLabel: 'Escolher data',
                        enabled: !_submitting,
                        errorText: _fieldErrors['ends_on'],
                      ),
                    ],
                  ),
                  const AppFormGap(),
                  if (_showDetails)
                    AppFormSection(
                      title: 'Contatos e detalhes',
                      children: [
                        TextField(
                          controller: _emergency,
                          enabled: !_submitting,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Telefone de emergência (opcional)',
                            errorText: _fieldErrors['emergency_phone'],
                          ),
                        ),
                        TextField(
                          controller: _policy,
                          enabled: !_submitting,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Número da apólice (opcional)',
                            errorText: _fieldErrors['policy_number'],
                          ),
                        ),
                        TextField(
                          controller: _brokerName,
                          enabled: !_submitting,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Corretor (opcional)',
                            errorText: _fieldErrors['broker_name'],
                          ),
                        ),
                        TextField(
                          controller: _brokerPhone,
                          enabled: !_submitting,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Telefone do corretor (opcional)',
                            errorText: _fieldErrors['broker_phone'],
                          ),
                        ),
                        TextField(
                          controller: _notes,
                          enabled: !_submitting,
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Observações (opcional)',
                            errorText: _fieldErrors['notes'],
                          ),
                        ),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: 'Contatos e detalhes',
                        icon: Icons.add,
                        variant: AppButtonVariant.tertiary,
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _showDetails = true),
                      ),
                    ),
                ],
              ),
            ),
            AppFormFooter(
              child: AppButton(
                label: _offline
                    ? 'Tentar de novo'
                    : (_editing ? 'Salvar seguro' : 'Registrar seguro'),
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
                expanded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
