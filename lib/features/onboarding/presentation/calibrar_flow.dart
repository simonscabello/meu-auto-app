import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_rollback_dialog.dart';
import 'package:meu_auto/features/onboarding/application/calibrar_provider.dart';
import 'package:meu_auto/features/onboarding/domain/calibrar_questions.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

class CalibrarFlow extends ConsumerStatefulWidget {
  const CalibrarFlow({
    super.key,
    required this.vehicleId,
    required this.currentMileageKm,
    this.newId,
  });

  final String vehicleId;
  final int currentMileageKm;
  final String Function()? newId;

  @override
  ConsumerState<CalibrarFlow> createState() => _CalibrarFlowState();
}

class _CalibrarFlowState extends ConsumerState<CalibrarFlow> {
  late final TextEditingController _mileage;
  List<MaintenancePlan>? _questions;
  int _index = 0;
  int _configured = 0;
  bool _done = false;
  bool _submitting = false;
  bool _offline = false;
  CivilDate? _occurredOn;
  String? _banner;
  Map<String, String> _fieldErrors = {};
  String? _inFlightId;

  @override
  void initState() {
    super.initState();
    final text = widget.currentMileageKm.toString();
    _mileage = TextEditingController(text: text)
      ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }

  @override
  void dispose() {
    _mileage.dispose();
    super.dispose();
  }

  void _capture(List<MaintenancePlan> plans) {
    _questions ??= selectCalibrarPlans(plans);
  }

  void _resetAnswer() {
    _occurredOn = null;
    _banner = null;
    _offline = false;
    _fieldErrors = {};
    _inFlightId = null;
    _submitting = false;
    final text = widget.currentMileageKm.toString();
    _mileage.text = text;
    _mileage.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }

  void _advance() {
    final questions = _questions ?? const <MaintenancePlan>[];
    if (_index + 1 >= questions.length) {
      setState(() {
        _submitting = false;
        _done = true;
      });
      return;
    }
    setState(() {
      _index++;
      _resetAnswer();
    });
  }

  Future<void> _skipAll() async {
    if (_submitting) return;
    await ref.read(calibrarSkipStoreProvider).markSkipped(widget.vehicleId);
    if (_configured > 0) {
      _invalidate();
      if (!mounted) return;
      setState(() => _done = true);
      return;
    }
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  Future<void> _seeCar() async {
    await ref.read(calibrarSkipStoreProvider).markSkipped(widget.vehicleId);
    _invalidate();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  void _invalidate() {
    invalidateAfterMaintenanceWrite(ref, widget.vehicleId);
    unawaited(ref.read(vehiclesProvider.notifier).reload());
  }

  Future<void> _confirm() async {
    final occurredOn = _occurredOn;
    final mileage = int.tryParse(_mileage.text.trim());
    if (occurredOn == null) {
      setState(() {
        _fieldErrors = {'occurred_on': 'Informe a data.'};
        _banner = null;
      });
      return;
    }
    if (mileage == null) {
      setState(() {
        _fieldErrors = {'mileage_km': 'Informe a quilometragem.'};
        _banner = null;
      });
      return;
    }

    final questions = _questions;
    if (questions == null || _index >= questions.length) return;

    setState(() {
      _submitting = true;
      _banner = null;
      _offline = false;
      _fieldErrors = {};
    });

    _inFlightId ??= widget.newId?.call() ?? newClientId();
    final draft = declaredBaselineDraft(
      id: _inFlightId!,
      occurredOn: occurredOn,
      mileageKm: mileage,
      plan: questions[_index],
    );

    try {
      await ref
          .read(maintenanceRecordRepositoryProvider)
          .create(widget.vehicleId, draft);
      if (!mounted) return;
      _configured++;
      _advance();
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
          await _confirm();
        }
        return;
      }

      setState(() {
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _banner = 'Algo deu errado. Tente novamente.';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await pickPastDate(context, initial: _occurredOn);
    if (picked == null || !mounted) return;
    setState(() {
      _occurredOn = picked;
      _fieldErrors = {
        for (final entry in _fieldErrors.entries)
          if (entry.key != 'occurred_on') entry.key: entry.value,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(maintenancePlansProvider(widget.vehicleId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _submitting) return;
        if (_done) {
          await _seeCar();
          return;
        }
        await _skipAll();
      },
      child: _shell(_body(plans)),
    );
  }

  Widget _body(AsyncValue<List<MaintenancePlan>> plans) {
    if (_done) {
      return _doneContent();
    }

    final cached = _questions;
    if (cached != null) {
      return _questionsBody(cached);
    }

    return plans.when(
      loading: () => const _CalibrarSkeleton(),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () =>
            ref.invalidate(maintenancePlansProvider(widget.vehicleId)),
      ),
      data: (list) {
        _capture(list);
        return _questionsBody(_questions ?? const <MaintenancePlan>[]);
      },
    );
  }

  Widget _questionsBody(List<MaintenancePlan> questions) {
    if (questions.isEmpty) {
      return _doneContent();
    }
    final plan = questions[_index];
    return CalibrarQuestionContent(
      progressLabel: '${_index + 1} de ${questions.length}',
      title: calibrarQuestionTitle(plan),
      occurredOn: _occurredOn,
      mileage: _mileage,
      submitting: _submitting,
      offline: _offline,
      banner: _banner,
      dateError: _fieldErrors['occurred_on'],
      mileageError: _fieldErrors['mileage_km'],
      currentMileageKm: widget.currentMileageKm,
      onPickDate: _pickDate,
      onConfirm: () => unawaited(_confirm()),
      onDontKnow: _advance,
      onSkipAll: () => unawaited(_skipAll()),
    );
  }

  Widget _doneContent() {
    return CalibrarDoneContent(
      configured: _configured,
      onSeeCar: _submitting ? null : () => unawaited(_seeCar()),
    );
  }

  Widget _shell(Widget body) {
    return AppScaffold(
      titleWidget: const SizedBox.shrink(),
      actions: [
        AppIconButton(
          label: 'Fechar',
          icon: Icons.close,
          onPressed: _submitting
              ? null
              : () {
                  if (_done) {
                    unawaited(_seeCar());
                    return;
                  }
                  unawaited(_skipAll());
                },
        ),
      ],
      body: body,
    );
  }
}

class CalibrarQuestionContent extends StatelessWidget {
  const CalibrarQuestionContent({
    super.key,
    required this.progressLabel,
    required this.title,
    required this.occurredOn,
    required this.mileage,
    required this.submitting,
    required this.offline,
    required this.onPickDate,
    required this.onConfirm,
    required this.onDontKnow,
    required this.onSkipAll,
    required this.currentMileageKm,
    this.banner,
    this.dateError,
    this.mileageError,
  });

  final String progressLabel;
  final String title;
  final CivilDate? occurredOn;
  final TextEditingController mileage;
  final bool submitting;
  final bool offline;
  final VoidCallback onPickDate;
  final VoidCallback onConfirm;
  final VoidCallback onDontKnow;
  final VoidCallback onSkipAll;
  final int currentMileageKm;
  final String? banner;
  final String? dateError;
  final String? mileageError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = occurredOn == null
        ? 'Escolher data'
        : formatCivilDateLong(occurredOn!);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          progressLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s8),
        Text(
          calibrarQuestionSubtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (banner != null) ...[
          const SizedBox(height: AppSpacing.s16),
          AuthFormBanner(message: banner!),
        ],
        const SizedBox(height: AppSpacing.s24),
        InkWell(
          onTap: submitting ? null : onPickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Data',
              errorText: dateError,
              errorMaxLines: 3,
            ),
            child: Text(
              dateLabel,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: occurredOn == null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        TextField(
          controller: mileage,
          enabled: !submitting,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submitting ? null : onConfirm(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(7),
          ],
          decoration: InputDecoration(
            labelText: 'Quilometragem',
            suffixText: 'km',
            helperText: 'Atual: ${formatKm(currentMileageKm)}',
            errorText: mileageError,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: AppSpacing.s32),
        AppButton(
          label: offline ? 'Tentar de novo' : 'Confirmar',
          loading: submitting,
          onPressed: onConfirm,
        ),
        const SizedBox(height: AppSpacing.s8),
        TextButton(
          onPressed: submitting ? null : onDontKnow,
          child: const Text('Não sei'),
        ),
        TextButton(
          onPressed: submitting ? null : onSkipAll,
          child: const Text('Pular tudo'),
        ),
      ],
    );
  }
}

class CalibrarDoneContent extends StatelessWidget {
  const CalibrarDoneContent({
    super.key,
    required this.configured,
    this.onSeeCar,
  });

  final int configured;
  final VoidCallback? onSeeCar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            configured == 0 ? 'Tudo bem' : 'Pronto',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            _doneBody(configured),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          AppButton(label: 'Ver meu carro', onPressed: onSeeCar),
        ],
      ),
    );
  }
}

String _doneBody(int configured) {
  if (configured == 0) {
    return 'Quando você souber, informe em Cuidados. '
        'O Meu Auto não inventa o que você não lembra.';
  }
  if (configured == 1) {
    return '1 cuidado já está no histórico. A partir de agora o Meu Auto '
        'avisa quando ele estiver perto.';
  }
  return '$configured cuidados já estão no histórico. A partir de agora '
      'o Meu Auto avisa quando estiverem perto.';
}

class _CalibrarSkeleton extends StatelessWidget {
  const _CalibrarSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.s24),
      child: AppSkeletonList(count: 4, itemHeight: 72),
    );
  }
}
