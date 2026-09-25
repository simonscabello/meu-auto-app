import 'dart:async';

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
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';
import 'package:meu_auto/features/odometer/domain/odometer_rollback.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_rollback_dialog.dart';
import 'package:meu_auto/features/onboarding/application/calibrar_provider.dart';
import 'package:meu_auto/features/onboarding/domain/calibrar_questions.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_choice_row.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_form_section.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_progress_bar.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// The history questions: when each item was last done. Asked after a vehicle
/// is registered, and again from Início while any are unanswered — always
/// with permission first.
///
/// The first screen is a single yes/no. Somebody who taps "Depois" is on the
/// dashboard in one tap. Each question is then a page of its own: the
/// question as the heading, two answers to choose from, the date and the
/// mileage only when the answer is "lembro", and one button at the foot.
///
/// Which questions get asked, and how they are worded, comes from the server.
/// Nothing here knows what a timing belt is.
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

enum _Step { intro, asking, done }

/// The two answers to "quando foi a última vez?".
///
/// [dontKnow] is an answer, not a skip: it is written down so the question
/// stops coming back, and it creates no service record.
enum CalibrarAnswer { remember, dontKnow }

class _CalibrarFlowState extends ConsumerState<CalibrarFlow> {
  late final TextEditingController _mileage;
  List<MaintenancePlan>? _questions;
  _Step _step = _Step.intro;
  int _index = 0;
  int _configured = 0;
  bool _submitting = false;
  bool _offline = false;
  CalibrarAnswer? _answer;
  CivilDate? _occurredOn;
  String? _banner;
  Map<String, String> _fieldErrors = {};
  String? _inFlightId;

  @override
  void initState() {
    super.initState();
    // Empty, not today's reading. Every answer here is about the past, and a
    // field prefilled with the current mileage was accepted as-is. The
    // current reading stays as the helper line, for reference.
    _mileage = TextEditingController();
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
    _answer = null;
    _occurredOn = null;
    _banner = null;
    _offline = false;
    _fieldErrors = {};
    _inFlightId = null;
    _submitting = false;
    _mileage.clear();
  }

  void _advance() {
    final questions = _questions ?? const <MaintenancePlan>[];
    if (_index + 1 >= questions.length) {
      setState(() {
        _submitting = false;
        _step = _Step.done;
      });
      return;
    }
    setState(() {
      _index++;
      _resetAnswer();
    });
  }

  Future<void> _startAsking() async {
    final questions = _questions;
    if (questions == null || questions.isEmpty) {
      await _seeCar();
      return;
    }
    setState(() {
      _step = _Step.asking;
      _index = 0;
      _resetAnswer();
    });
  }

  Future<void> _skipAll() async {
    if (_submitting) return;
    await ref.read(calibrarSkipStoreProvider).markSkipped(widget.vehicleId);
    if (_configured > 0) {
      _invalidate();
      if (!mounted) return;
      setState(() => _step = _Step.done);
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

  /// "Não sei" is an answer, and it is written down.
  ///
  /// It records that the owner was asked and does not remember — which is what
  /// stops the question coming back. It deliberately does NOT create a service
  /// record.
  Future<void> _dontKnow() async {
    final questions = _questions;
    if (questions == null || _index >= questions.length) return;
    final plan = questions[_index];

    setState(() => _submitting = true);
    try {
      await ref
          .read(maintenancePlanRepositoryProvider)
          .update(
            plan.id,
            const PlanUpdate.history(MaintenanceHistoryStatus.unknown),
          );
    } on ApiFailure {
      // Not worth stopping the flow over. The question simply comes back next
      // time, which is the old behaviour and is not harmful.
    }
    if (!mounted) return;
    _advance();
  }

  Future<void> _confirm({bool correction = false}) async {
    final occurredOn = _occurredOn;
    final mileage = kmFromField(_mileage.text);
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
      correction: correction,
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
          await _confirm(correction: true);
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

  void _choose(CalibrarAnswer answer) {
    if (_submitting) return;
    setState(() {
      _answer = answer;
      _fieldErrors = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(maintenancePlansProvider(widget.vehicleId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _submitting) return;
        if (_step == _Step.done) {
          await _seeCar();
          return;
        }
        await _skipAll();
      },
      child: _page(plans),
    );
  }

  /// The intro, the questions and the end carry their own way out, so they
  /// have no app bar. Loading and a failed load do not, and get the close
  /// button instead — without it, a list that never arrives would be a page
  /// with no exit on iOS, where the swipe back is held by the `PopScope`.
  Widget _page(AsyncValue<List<MaintenancePlan>> plans) {
    if (_step == _Step.done) {
      return AppScaffold(body: _doneContent());
    }

    final cached = _questions;
    if (cached != null) {
      return AppScaffold(body: _stepBody(cached));
    }

    return plans.when(
      loading: () => _closable(const _CalibrarSkeleton()),
      error: (error, _) => _closable(
        AppErrorState.fromError(
          error: error,
          onRetry: () =>
              ref.invalidate(maintenancePlansProvider(widget.vehicleId)),
        ),
      ),
      data: (list) {
        _capture(list);
        return AppScaffold(
          body: _stepBody(_questions ?? const <MaintenancePlan>[]),
        );
      },
    );
  }

  Widget _stepBody(List<MaintenancePlan> questions) {
    if (questions.isEmpty) {
      return CalibrarDoneContent(
        configured: _configured,
        nothingToAsk: true,
        onSeeCar: _submitting ? null : () => unawaited(_seeCar()),
      );
    }
    if (_step == _Step.intro) {
      return CalibrarIntroContent(
        questionCount: questions.length,
        onStart: () => unawaited(_startAsking()),
        onLater: () => unawaited(_seeCar()),
      );
    }

    final plan = questions[_index];
    return CalibrarQuestionContent(
      progressLabel: '${_index + 1} de ${questions.length}',
      progress: (_index + 1) / questions.length,
      title: calibrarQuestionTitle(plan),
      answer: _answer,
      onAnswer: _choose,
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
      onDontKnow: () => unawaited(_dontKnow()),
      onSkipAll: () => unawaited(_skipAll()),
    );
  }

  Widget _doneContent() {
    return CalibrarDoneContent(
      configured: _configured,
      onSeeCar: _submitting ? null : () => unawaited(_seeCar()),
    );
  }

  Widget _closable(Widget body) {
    return AppScaffold(
      titleWidget: const SizedBox.shrink(),
      // The close button is the way out; a back arrow beside it would be a
      // second one doing the same thing.
      leading: const SizedBox.shrink(),
      actions: [
        AppIconButton(
          label: 'Fechar',
          icon: Icons.close,
          onPressed: _submitting ? null : () => unawaited(_skipAll()),
        ),
      ],
      body: body,
    );
  }
}

/// One question, before any question: is this worth doing now at all?
///
/// It exists so the answer "não agora" costs a single tap. Nothing is lost by
/// saying no — the same questions are waiting on Início afterwards.
///
/// The heading does not say "Carro cadastrado": the flow is also opened from
/// Início for a car registered long ago, and it cannot tell the two apart.
class CalibrarIntroContent extends StatelessWidget {
  const CalibrarIntroContent({
    super.key,
    required this.questionCount,
    required this.onStart,
    required this.onLater,
  });

  final int questionCount;
  final VoidCallback onStart;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _CalibrarPage(
      actions: [
        AppButton(label: 'Contar agora', onPressed: onStart, expanded: true),
        const SizedBox(height: AppSpacing.s8),
        AppButton(
          label: 'Depois',
          variant: AppButtonVariant.tertiary,
          onPressed: onLater,
          expanded: true,
        ),
      ],
      children: [
        Semantics(
          header: true,
          child: Text(
            'Quando foi a última vez?',
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          calibrarIntroBody(questionCount),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// "2 perguntas rápidas…", with the singular said as a singular.
String calibrarIntroBody(int questionCount) {
  final count = questionCount == 1
      ? '1 pergunta rápida'
      : '$questionCount perguntas rápidas';
  return '$count sobre o que já foi feito no carro, para o Meu Auto saber '
      'quando avisar. Dá para responder depois.';
}

/// One history question: the question as the heading, the two answers as
/// rows to choose from, the date and the mileage only once the answer is
/// "lembro", and "Continuar" held at the foot of the page.
///
/// "Pular tudo" sits by the progress, as text: it leaves the questions, and
/// the ones not reached stay unasked for later. "Não sei" is not there — it
/// is an answer, and it is written down.
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
    this.progress,
    this.answer,
    this.onAnswer,
    this.banner,
    this.dateError,
    this.mileageError,
  });

  /// "2 de 5".
  final String progressLabel;

  /// Which question this is, over how many. A real count, so the bar is
  /// honest.
  final double? progress;

  final String title;

  /// The answer picked so far, or null before one is.
  final CalibrarAnswer? answer;
  final ValueChanged<CalibrarAnswer>? onAnswer;

  final CivilDate? occurredOn;
  final TextEditingController mileage;
  final bool submitting;
  final bool offline;
  final VoidCallback onPickDate;

  /// "Continuar" with [CalibrarAnswer.remember]: writes the date and mileage.
  final VoidCallback onConfirm;

  /// "Continuar" with [CalibrarAnswer.dontKnow]: records that nobody knows.
  final VoidCallback onDontKnow;

  final VoidCallback onSkipAll;
  final int currentMileageKm;
  final String? banner;
  final String? dateError;
  final String? mileageError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remembers = answer == CalibrarAnswer.remember;
    final VoidCallback? onContinue = switch (answer) {
      CalibrarAnswer.remember => onConfirm,
      CalibrarAnswer.dontKnow => onDontKnow,
      null => null,
    };
    final choose = submitting || onAnswer == null
        ? null
        : (CalibrarAnswer? picked) {
            if (picked != null) onAnswer!(picked);
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s8,
              AppSpacing.page,
              AppSpacing.s24,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Pergunta $progressLabel',
                      excludeSemantics: true,
                      child: Text(
                        progressLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  // Pulled into the gutter by the button's own padding, so
                  // the words end where the bar under them ends.
                  Transform.translate(
                    offset: const Offset(AppSpacing.s12, 0),
                    child: AppButton(
                      label: 'Pular tudo',
                      variant: AppButtonVariant.tertiary,
                      onPressed: submitting ? null : onSkipAll,
                    ),
                  ),
                ],
              ),
              if (progress != null) AppProgressBar(value: progress!),
              const SizedBox(height: AppSpacing.s32),
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                calibrarQuestionSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              if (banner != null) AuthFormBanner(message: banner!),
              AppGroup(
                children: [
                  AppChoiceRow<CalibrarAnswer?>(
                    value: CalibrarAnswer.remember,
                    groupValue: answer,
                    label: 'Lembro quando foi',
                    subtitle: 'Data e quilometragem aproximadas servem',
                    enabled: !submitting,
                    onChanged: choose,
                  ),
                  AppChoiceRow<CalibrarAnswer?>(
                    value: CalibrarAnswer.dontKnow,
                    groupValue: answer,
                    label: 'Não sei',
                    subtitle: 'O item fica sem data da última vez',
                    enabled: !submitting,
                    onChanged: choose,
                  ),
                ],
              ),
              if (remembers) ...[
                const SizedBox(height: AppSpacing.block),
                AppDateField(
                  value: occurredOn,
                  onPick: onPickDate,
                  enabled: !submitting,
                  errorText: dateError,
                ),
                const SizedBox(height: AppSpacing.s12),
                AppKmField(
                  controller: mileage,
                  enabled: !submitting,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submitting ? null : onConfirm(),
                  label: 'Quilometragem na época',
                  helperText: currentMileageKm > 0
                      ? 'Hoje o carro está com ${formatKm(currentMileageKm)}.'
                      : null,
                  errorText: mileageError,
                ),
              ],
            ],
          ),
        ),
        AppFormFooter(
          child: AppButton(
            label: offline && remembers ? 'Tentar de novo' : 'Continuar',
            loading: submitting,
            onPressed: onContinue,
            expanded: true,
          ),
        ),
      ],
    );
  }
}

/// The end of the questions: what was recorded, and the way back to the car.
class CalibrarDoneContent extends StatelessWidget {
  const CalibrarDoneContent({
    super.key,
    required this.configured,
    this.onSeeCar,
    this.nothingToAsk = false,
  });

  /// How many answers became a record.
  final int configured;

  final VoidCallback? onSeeCar;

  /// The server had no question to ask for this car — every item already has
  /// an answer or a date — so nothing was asked at all.
  final bool nothingToAsk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, body) = _doneCopy(configured, nothingToAsk: nothingToAsk);
    return _CalibrarPage(
      actions: [
        AppButton(label: 'Ver meu carro', onPressed: onSeeCar, expanded: true),
      ],
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

(String, String) _doneCopy(int configured, {required bool nothingToAsk}) {
  if (nothingToAsk) {
    return (
      'Nada a perguntar agora',
      'As perguntas sobre este carro já foram respondidas.',
    );
  }
  if (configured == 0) {
    return (
      'Sem datas por enquanto',
      'Quando lembrar, informe na aba Manutenção, em "Sem data da última '
          'vez". Até lá, não há como avisar sobre esses itens.',
    );
  }
  if (configured == 1) {
    return (
      'Pronto',
      '1 item já está no histórico. O Meu Auto avisa quando ele estiver '
          'perto de vencer.',
    );
  }
  return (
    'Pronto',
    '$configured itens já estão no histórico. O Meu Auto avisa quando '
        'estiverem perto de vencer.',
  );
}

/// A page of the flow with no form: the words at the top, the buttons held
/// at the foot, where the thumb is.
class _CalibrarPage extends StatelessWidget {
  const _CalibrarPage({required this.children, required this.actions});

  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s48,
              AppSpacing.page,
              AppSpacing.s24,
            ),
            children: children,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.s12,
            AppSpacing.page,
            AppSpacing.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
        ),
      ],
    );
  }
}

/// The shape of the first page while the questions load: a heading and two
/// lines.
class _CalibrarSkeleton extends StatelessWidget {
  const _CalibrarSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: AppSpacing.screenHeaded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 240, height: 28),
          SizedBox(height: AppSpacing.s16),
          AppSkeleton(width: double.infinity, height: 16),
          SizedBox(height: AppSpacing.s8),
          AppSkeleton(width: 200, height: 16),
        ],
      ),
    );
  }
}
