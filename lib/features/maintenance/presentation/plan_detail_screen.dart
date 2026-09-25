import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/domain/phrases.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_profile_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';
import 'package:meu_auto/features/maintenance/domain/plan_progress.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_periodicity.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_detail_header.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_fact_row.dart';
import 'package:meu_auto/shared/widgets/app_facts_strip.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_overflow_menu.dart';
import 'package:meu_auto/shared/widgets/app_progress_bar.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  bool _markingDone = false;

  /// Taken on the first tap on "Marcar como feito" and kept until it lands:
  /// a retry after a dropped connection is the same record, not a second one.
  String? _doneId;

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(selectedVehicleProvider).valueOrNull;
    if (vehicle == null) {
      return const AppScaffold(title: 'Manutenção', body: SizedBox.shrink());
    }

    final key = (vehicleId: vehicle.id, planId: widget.planId);
    final planAsync = ref.watch(maintenancePlanProvider(key));
    final records = ref.watch(maintenanceRecordsProvider(vehicle.id));

    return planAsync.when(
      loading: () => const AppScaffold(
        title: 'Manutenção',
        body: Padding(
          padding: AppSpacing.screen,
          child: AppSkeletonList(count: 3, itemHeight: 120),
        ),
      ),
      error: (error, _) {
        final inactive =
            error is ApiFailure && error.code == ApiErrorCode.notFound;
        return AppScaffold(
          title: 'Manutenção',
          body: inactive
              ? AppErrorState(
                  message: 'Este item não está mais sendo acompanhado.',
                  onRetry: () => ref.invalidate(maintenancePlanProvider(key)),
                )
              : AppErrorState.fromError(
                  error: error,
                  onRetry: () => ref.invalidate(maintenancePlanProvider(key)),
                ),
        );
      },
      data: (plan) {
        final history = _historyOf(records, plan.maintenanceItemId);
        final historyLoading = records.isLoading && records.value == null;
        final isCare = plan.itemKind == MaintenanceItemKind.care;
        void adjust() => showPlanPeriodicitySheet(
          context,
          vehicleId: vehicle.id,
          plan: plan,
        );

        return AppScaffold(
          title: 'Manutenção',
          actions: [
            AppIconButton(
              label: isCare ? 'Editar lembrete' : 'Editar intervalo',
              icon: Icons.edit_outlined,
              onPressed: adjust,
            ),
            PlanDetailMenu(
              onKeepHistoryOnly:
                  plan.status == MaintenanceStatus.semPeriodicidade
                  ? null
                  : () => _clearIntervals(context, ref, vehicle.id, plan),
              onNotApplicable: () =>
                  _markNotApplicable(context, ref, vehicle.id, plan),
              onDeactivate: () => _deactivate(context, ref, vehicle.id, plan),
            ),
          ],
          body: PlanDetailContent(
            plan: plan,
            history: history,
            historyLoading: historyLoading,
            onRegister: () => context.push(
              AppRoutes.maintenanceNew,
              extra: plan.toCatalogueItem(),
            ),
            onMarkDone: isCare
                ? () => unawaited(_markDone(vehicle.id, plan))
                : null,
            markingDone: _markingDone,
            onAdjustInterval: adjust,
            onHistoryUnknown: (status) =>
                _setHistory(context, ref, vehicle.id, plan, status),
            onOpenRecord: (record) =>
                context.push(AppRoutes.maintenanceRecord(record.id)),
          ),
        );
      },
    );
  }

  List<MaintenanceRecord> _historyOf(
    AsyncValue<PagedState<MaintenanceRecord>> records,
    String itemId,
  ) {
    final page = records.valueOrNull;
    if (page == null) return const [];
    return historyOfItem(page.items, itemId);
  }

  /// The same one-tap write as "Feito" on Manutenção: a record for today with
  /// this one item, and an undo beside the confirmation.
  Future<void> _markDone(String vehicleId, MaintenancePlan plan) async {
    if (_markingDone) return;
    setState(() => _markingDone = true);
    final id = _doneId ??= newClientId();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final created = await ref
          .read(maintenanceRecordRepositoryProvider)
          .create(
            vehicleId,
            MaintenanceRecordDraft(
              id: id,
              occurredOn: CivilDate.todayLocal(),
              kind: MaintenanceRecordKind.performed,
              items: [MaintenanceRecordLineDraft(item: plan.toCatalogueItem())],
            ),
          );
      _doneId = null;
      invalidateAfterMaintenanceWrite(ref, vehicleId);
      if (!mounted) return;
      setState(() => _markingDone = false);
      showAppSnackBar(
        messenger,
        message: '${plan.itemName}: registrado hoje.',
        onUndo: () => unawaited(_undoDone(vehicleId, created.id)),
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _markingDone = false);
      showAppErrorSnackBar(
        messenger,
        message: ApiFormErrors.bannerOf(failure) ?? failure.message,
      );
    }
  }

  Future<void> _undoDone(String vehicleId, String recordId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(maintenanceRecordRepositoryProvider).delete(recordId);
      invalidateAfterMaintenanceWrite(ref, vehicleId);
    } on ApiFailure catch (failure) {
      showAppErrorSnackBar(messenger, message: failure.message);
    }
  }
}

Future<void> _clearIntervals(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
  MaintenancePlan plan,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Guardar só o histórico?',
    message:
        'Este item deixa de vencer. O que você registrar continua aqui, mas '
        'o Meu Auto não avisa mais uma data nem uma quilometragem.',
    confirmLabel: 'Só guardar histórico',
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref
        .read(maintenancePlanRepositoryProvider)
        .update(plan.id, const PlanUpdate.clearIntervals());
    invalidateAfterPlanWrite(ref, vehicleId);
    if (!context.mounted) return;
    showAppSnackBar(
      ScaffoldMessenger.of(context),
      message: 'Este item agora só guarda histórico.',
    );
  } on ApiFailure catch (failure) {
    if (!context.mounted) return;
    showAppErrorSnackBar(
      ScaffoldMessenger.of(context),
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

/// "Meu carro não tem isso."
///
/// A correction, not a deletion: the plan stays, keeps its interval and can be
/// brought back from the profile screen.
Future<void> _markNotApplicable(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
  MaintenancePlan plan,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Seu carro não usa ${plan.itemName.toLowerCase()}?',
    message:
        'O item sai das listas e não vira lembrete. Para desfazer, volte em '
        '"O que o seu carro tem".',
    confirmLabel: 'Não usa',
  );
  if (!confirmed || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await ref
        .read(maintenancePlanRepositoryProvider)
        .update(
          plan.id,
          const PlanUpdate.applicability(
            strategy: MaintenanceStrategy.notApplicable,
          ),
        );
    invalidateAfterProfileWrite(ref, vehicleId);
    navigator.pop();
    showAppSnackBar(messenger, message: '${plan.itemName} saiu da lista.');
  } on ApiFailure catch (failure) {
    if (!context.mounted) return;
    showAppErrorSnackBar(
      messenger,
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

/// "Não sei" and "nunca foi feito", recorded as what they are.
///
/// Neither writes a maintenance record. A record asserts a date and a mileage,
/// and both of these answers exist precisely because the owner does not have
/// them.
Future<void> _setHistory(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
  MaintenancePlan plan,
  MaintenanceHistoryStatus status,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(maintenancePlanRepositoryProvider)
        .update(plan.id, PlanUpdate.history(status));
    invalidateAfterProfileWrite(ref, vehicleId);
    showAppSnackBar(
      messenger,
      message: status == MaintenanceHistoryStatus.never
          ? 'Anotado. Contamos a partir de quando o carro era novo.'
          : 'Anotado. Quando fizer, registre aqui e a contagem começa.',
    );
  } on ApiFailure catch (failure) {
    if (!context.mounted) return;
    showAppErrorSnackBar(
      messenger,
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

Future<void> _deactivate(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
  MaintenancePlan plan,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Parar de acompanhar ${plan.itemName.toLowerCase()}?',
    message:
        'O Meu Auto deixa de avisar sobre este item. O que já foi registrado '
        'continua no histórico, e dá para voltar a acompanhar depois.',
    confirmLabel: 'Parar de acompanhar',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await ref.read(maintenancePlanRepositoryProvider).deactivate(plan.id);
    invalidateAfterPlanWrite(ref, vehicleId);
    navigator.pop();
    showAppSnackBar(
      messenger,
      message: 'Não vamos mais avisar sobre este item.',
    );
  } on ApiFailure catch (failure) {
    showAppErrorSnackBar(
      messenger,
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

/// The plan's rarer choices, in the ⋮ at the end of the app bar.
///
/// What someone opens this screen to do is register the service; changing how
/// often it comes due is the pencil beside this menu. The rest is a correction
/// made once, and stopping is the destructive one — last, in red, confirmed.
class PlanDetailMenu extends StatelessWidget {
  const PlanDetailMenu({
    super.key,
    this.onKeepHistoryOnly,
    this.onNotApplicable,
    this.onDeactivate,
  });

  final VoidCallback? onKeepHistoryOnly;
  final VoidCallback? onNotApplicable;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (onNotApplicable != null)
        AppMenuAction(
          label: 'Meu carro não tem isso',
          onSelected: onNotApplicable!,
        ),
      if (onKeepHistoryOnly != null)
        AppMenuAction(
          label: 'Só guardar o histórico',
          onSelected: onKeepHistoryOnly!,
        ),
      if (onDeactivate != null)
        AppMenuAction(
          label: 'Parar de acompanhar',
          destructive: true,
          onSelected: onDeactivate!,
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return AppOverflowMenu(actions: actions);
  }
}

/// The plan as pure presentation.
///
/// Read top to bottom it answers, in order: which item and how it stands (the
/// header, with the bar when the figures allow one), when it is due again (the
/// facts strip), the one thing to do about it, how it is looked after, and
/// what was done before.
class PlanDetailContent extends StatelessWidget {
  const PlanDetailContent({
    super.key,
    required this.plan,
    this.history = const [],
    this.historyLoading = false,
    this.onRegister,
    this.onMarkDone,
    this.markingDone = false,
    this.onAdjustInterval,
    this.onHistoryUnknown,
    this.onOpenRecord,
  });

  final MaintenancePlan plan;
  final List<MaintenanceRecord> history;
  final bool historyLoading;

  /// Opens the service form with this item already chosen.
  final VoidCallback? onRegister;

  /// A care habit's one tap: done today. When set on a care item it replaces
  /// [onRegister] as the screen's action — a habit is marked, not filled in.
  final VoidCallback? onMarkDone;
  final bool markingDone;

  final VoidCallback? onAdjustInterval;

  /// "Não sei" / "nunca foi feito". Only offered while there is no baseline —
  /// once a service is recorded, the record is the answer.
  final ValueChanged<MaintenanceHistoryStatus>? onHistoryUnknown;

  final ValueChanged<MaintenanceRecord>? onOpenRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = AppStatus.fromWire(plan.status.wire);
    final visual = statusColors(status, theme.brightness);
    final isCare = plan.itemKind == MaintenanceItemKind.care;
    final noBaseline = plan.status == MaintenanceStatus.semBaseline;
    final progress = planProgress(plan);
    final facts = _dueFacts(plan);
    final showStrip = facts.length >= 2;
    final interval = intervalPhrase(
      km: plan.intervalKm,
      months: plan.intervalMonths,
      days: plan.intervalDays,
    );
    final notes = plan.notes?.trim();
    // One rule, one place. The two answers about the past make sense only while
    // there is nothing to measure from AND nobody has answered yet: once a
    // service is recorded the record IS the answer, and once somebody has said
    // "não sei" asking again is the nagging this change exists to remove.
    final canAnswerHistory =
        onHistoryUnknown != null &&
        noBaseline &&
        plan.historyStatus == MaintenanceHistoryStatus.notAsked;

    return ListView(
      padding: AppSpacing.screenHeaded,
      children: [
        AppDetailHeader(
          title: plan.itemName,
          status: status,
          statusLabel: _statusLabel(plan),
          phrase: _statePhrase(plan),
        ),
        // Not on a late item: a full red bar under a red badge and a red
        // sentence is the same fact a third time, and turns the screen into
        // an error state.
        if (progress != null && plan.status != MaintenanceStatus.vencido) ...[
          const SizedBox(height: AppSpacing.s16),
          AppProgressBar(
            value: progress,
            color: status.isLoud ? visual.foreground : null,
          ),
        ],
        if (showStrip) ...[
          const SizedBox(height: AppSpacing.s24),
          AppFactsStrip(facts: facts),
        ],
        if (isCare && onMarkDone != null) ...[
          const SizedBox(height: AppSpacing.s24),
          AppButton(
            label: 'Marcar como feito',
            loading: markingDone,
            onPressed: markingDone ? null : onMarkDone,
            expanded: true,
          ),
        ] else if (noBaseline) ...[
          const SizedBox(height: appGroupGap),
          // Without a date the item cannot come due, so the question the screen
          // asks first is when it was last done — with the two honest ways of
          // not knowing right under it.
          const AppSectionHeader(
            title: 'Quando foi a última vez?',
            subtitle: 'Com a data e a quilometragem, dá para avisar a próxima.',
          ),
          AppButton(
            label: 'Informar a última vez',
            onPressed: onRegister,
            expanded: true,
          ),
          if (canAnswerHistory) ...[
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Não sei quando foi',
                    variant: AppButtonVariant.tertiary,
                    onPressed: () =>
                        onHistoryUnknown!(MaintenanceHistoryStatus.unknown),
                  ),
                ),
                Expanded(
                  child: AppButton(
                    label: 'Nunca foi feito',
                    variant: AppButtonVariant.tertiary,
                    onPressed: () =>
                        onHistoryUnknown!(MaintenanceHistoryStatus.never),
                  ),
                ),
              ],
            ),
          ],
        ] else if (onRegister != null) ...[
          const SizedBox(height: AppSpacing.s24),
          AppButton(
            label: 'Registrar manutenção',
            onPressed: onRegister,
            expanded: true,
          ),
        ],
        const SizedBox(height: appGroupGap),
        AppGroup(
          title: 'Detalhes',
          dividerIndent: AppGroup.textIndent,
          footnote: _footnote(plan, hasInterval: interval != null),
          children: [
            // Stacked, not inline: "A cada 10.000 km ou 12 meses" is a
            // sentence, and squeezed into the right-hand column it broke
            // before its last word.
            AppFactRow(
              label: 'Intervalo',
              value: interval == null
                  ? 'Sem intervalo'
                  : capitalizeFirst(interval),
              onTap: onAdjustInterval,
            ),
            // "Nunca foi feito" counts from the car being new: said where the
            // last service would be, instead of a 0 km visit that never
            // happened.
            if (plan.countsFromNew)
              const AppFactRow(
                label: 'Última vez',
                value:
                    'Nunca foi feito — contamos a partir de quando o carro '
                    'era novo',
              ),
            if (!showStrip)
              for (final fact in facts)
                AppFactRow(
                  label: fact.label,
                  value: fact.unit == null
                      ? fact.value
                      : '${fact.value} ${fact.unit}',
                  inline: true,
                ),
            if (notes != null && notes.isNotEmpty)
              AppFactRow(label: 'Observação', value: notes),
          ],
        ),
        const SizedBox(height: appGroupGap),
        if (historyLoading) ...[
          const AppSectionHeader(title: 'Histórico'),
          const AppSkeleton(width: double.infinity, height: 72),
        ] else
          AppGroup(
            title: 'Histórico',
            dividerIndent: AppGroup.textIndent,
            footnote: history.isEmpty
                ? 'Nenhum registro deste item ainda.'
                : null,
            children: [
              for (var i = 0; i < history.length; i++)
                _HistoryRow(
                  key: ValueKey(history[i].id),
                  record: history[i],
                  previous: i + 1 < history.length ? history[i + 1] : null,
                  itemId: plan.maintenanceItemId,
                  onTap: onOpenRecord == null
                      ? null
                      : () => onOpenRecord!(history[i]),
                ),
            ],
          ),
      ],
    );
  }
}

/// The badge's word, when the strategy changes it.
///
/// A condition-based item — a tyre — that has run its suggested distance is
/// `vencido` on the wire, and is not a deadline: the badge says "Vale checar".
String? _statusLabel(MaintenancePlan plan) {
  if (plan.strategy != MaintenanceStrategy.conditionBased) return null;
  return switch (plan.status) {
    MaintenanceStatus.vencido => 'Vale checar',
    MaintenanceStatus.venceEmBreve => 'Checar em breve',
    _ => null,
  };
}

/// The sentence beside the badge: how late or how far, in the words Início
/// uses for the same item — "Venceu há 13 dias", "Faltam 2.000 km ou
/// 21/03/2027".
///
/// The badge already names the state, so a state with no figure to add says
/// nothing rather than repeating it.
String? _statePhrase(MaintenancePlan plan) {
  switch (plan.status) {
    case MaintenanceStatus.semBaseline:
      if (plan.historyStatus == MaintenanceHistoryStatus.unknown) {
        return 'Você não lembra quando foi';
      }
      return plan.itemKind == MaintenanceItemKind.care
          ? planStatusPhrase(plan)
          : null;
    case MaintenanceStatus.semPeriodicidade:
      return plan.strategy == MaintenanceStrategy.inspection
          ? 'Verificar na revisão'
          : null;
    case MaintenanceStatus.vencido || MaintenanceStatus.venceEmBreve:
      if (plan.strategy == MaintenanceStrategy.conditionBased) return null;
      return urgencyPhrase(
            remainingKm: plan.remainingKm,
            remainingDays: plan.remainingDays,
          ) ??
          planStatusPhrase(plan);
    case MaintenanceStatus.emDia:
      return upcomingSummary(
        remainingKm: plan.remainingKm,
        remainingDays: plan.remainingDays,
        dueOn: plan.dueOn,
      );
    case MaintenanceStatus.naoSeAplica || MaintenanceStatus.desconhecido:
      return null;
  }
}

/// When it was last done and when it is due again, as the figures the server
/// sent. Read across: the past on the left, the next on the right.
List<AppFact> _dueFacts(MaintenancePlan plan) {
  final facts = <AppFact>[];
  final lastOn = plan.lastOccurredOn;
  final lastKm = plan.lastMileageKm;
  if (!plan.countsFromNew) {
    if (lastOn != null) {
      facts.add(AppFact(label: 'Última vez', value: formatCivilDate(lastOn)));
    } else if (lastKm != null) {
      facts.add(
        AppFact(label: 'Última vez', value: formatKmNumber(lastKm), unit: 'km'),
      );
    }
  }
  final dueKm = plan.dueAtKm;
  final dueOn = plan.dueOn;
  if (dueKm != null) {
    facts.add(
      AppFact(label: 'Próxima', value: formatKmNumber(dueKm), unit: 'km'),
    );
  }
  if (dueOn != null) {
    facts.add(
      AppFact(
        // "Ou em": whichever comes first, beside the distance it competes with.
        label: dueKm == null ? 'Próxima' : 'Ou em',
        value: formatCivilDate(dueOn),
      ),
    );
  }
  return facts;
}

/// How the item is looked after, and where a suggested interval came from.
String? _footnote(MaintenancePlan plan, {required bool hasInterval}) {
  final parts = [
    ?strategyExplanation(plan),
    if (plan.origin == MaintenancePlanOrigin.suggested &&
        hasInterval &&
        plan.itemKind != MaintenanceItemKind.care)
      'O intervalo sugerido é uma referência de mercado, não do fabricante. '
          'Se o manual disser outro, ajuste.',
  ];
  return parts.isEmpty ? null : parts.join(' ');
}

/// One earlier service of this item: when, at what mileage and how far from
/// the one before, and what this line cost.
class _HistoryRow extends StatelessWidget with GroupedRow {
  const _HistoryRow({
    super.key,
    required this.record,
    required this.itemId,
    this.previous,
    this.onTap,
  });

  final MaintenanceRecord record;
  final MaintenanceRecord? previous;
  final String itemId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final km = record.mileageKm;
    final previousKm = previous?.mileageKm;
    final delta = km == null || previousKm == null
        ? null
        : mileageSincePreviousPhrase(km, previousKm);
    final subtitle = [
      if (km != null) formatKm(km),
      ?delta,
      if (record.kind == MaintenanceRecordKind.declared) 'Informado',
    ].join(' · ');

    return AppListRow(
      title: formatCivilDateLong(record.occurredOn),
      subtitle: subtitle.isEmpty ? null : subtitle,
      value: _costOf(record)?.format(),
      strongValue: true,
      onTap: onTap,
      showChevron: onTap != null,
    );
  }

  /// What this item cost on that visit: its own line when the line says, or
  /// the whole bill when the bill was for this item alone.
  Money? _costOf(MaintenanceRecord record) {
    for (final line in record.items) {
      if (line.maintenanceItemId != itemId) continue;
      final cost = line.costCents;
      if (cost != null && cost.cents > 0) return cost;
    }
    if (record.items.length == 1 && record.totalCostCents.cents > 0) {
      return record.totalCostCents;
    }
    return null;
  }
}
