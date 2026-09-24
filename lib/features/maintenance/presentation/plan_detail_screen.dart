import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_profile_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';
import 'package:meu_auto/features/maintenance/domain/plan_progress.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_periodicity.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_fact_row.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_progress_bar.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(selectedVehicleProvider).valueOrNull;
    if (vehicle == null) {
      return const AppScaffold(title: 'Manutenção', body: SizedBox.shrink());
    }

    final planAsync = ref.watch(
      maintenancePlanProvider((vehicleId: vehicle.id, planId: planId)),
    );
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
                  onRetry: () => ref.invalidate(
                    maintenancePlanProvider((
                      vehicleId: vehicle.id,
                      planId: planId,
                    )),
                  ),
                )
              : AppErrorState.fromError(
                  error: error,
                  onRetry: () => ref.invalidate(
                    maintenancePlanProvider((
                      vehicleId: vehicle.id,
                      planId: planId,
                    )),
                  ),
                ),
        );
      },
      data: (plan) {
        final history = _historyOf(records, plan.maintenanceItemId);
        final historyLoading = records.isLoading && records.value == null;

        return AppScaffold(
          title: plan.itemName,
          actions: [
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
            onAdjustInterval: () => showPlanPeriodicitySheet(
              context,
              vehicleId: vehicle.id,
              plan: plan,
            ),
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
        'Este item deixa de vencer. Ele continua agrupando o que você '
        'registrar, mas o Meu Auto não vai mais avisar uma data ou uma '
        'quilometragem.',
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
    showAppSnackBar(
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
        'Ele sai de todas as listas e não vira lembrete. '
        'Se você mudar de ideia, é só voltar em "O que o seu carro tem".',
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
    showAppSnackBar(
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
    showAppSnackBar(
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
    showAppSnackBar(
      messenger,
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

/// The plan's rarer choices, out of the way of the common one.
///
/// What someone opens this screen to do is register the service or change
/// how often it comes due; the rest is a correction made once, and belongs
/// in a menu.
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
    final items = <PopupMenuEntry<VoidCallback>>[
      if (onNotApplicable != null)
        PopupMenuItem(
          value: onNotApplicable,
          child: const Text('Meu carro não tem isso'),
        ),
      if (onKeepHistoryOnly != null)
        PopupMenuItem(
          value: onKeepHistoryOnly,
          child: const Text('Só guardar o histórico'),
        ),
      if (onDeactivate != null)
        PopupMenuItem(
          value: onDeactivate,
          child: Text(
            'Parar de acompanhar',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Mais opções',
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => items,
      onSelected: (action) => action(),
    );
  }
}

/// The plan as pure presentation: the state at the top, the facts as one
/// group, the one thing to do, and the item's own history.
class PlanDetailContent extends StatelessWidget {
  const PlanDetailContent({
    super.key,
    required this.plan,
    this.history = const [],
    this.historyLoading = false,
    this.onRegister,
    this.onAdjustInterval,
    this.onHistoryUnknown,
    this.onOpenRecord,
  });

  final MaintenancePlan plan;
  final List<MaintenanceRecord> history;
  final bool historyLoading;
  final VoidCallback? onRegister;
  final VoidCallback? onAdjustInterval;

  /// "Não sei" / "nunca foi feito". Only offered while there is no baseline —
  /// once a service is recorded, the record is the answer.
  final ValueChanged<MaintenanceHistoryStatus>? onHistoryUnknown;

  final ValueChanged<MaintenanceRecord>? onOpenRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = AppStatus.fromWire(plan.status.wire);
    final visual = statusColors(status, theme.brightness);
    final last = lastDonePhrase(
      occurredOn: plan.lastOccurredOn,
      mileageKm: plan.lastMileageKm,
    );
    final next = dueNextPhrase(dueAtKm: plan.dueAtKm, dueOn: plan.dueOn);
    final interval = intervalPhrase(
      km: plan.intervalKm,
      months: plan.intervalMonths,
      days: plan.intervalDays,
    );
    final howItWorks = strategyExplanation(plan);
    final noBaseline = plan.status == MaintenanceStatus.semBaseline;
    final headline = planDetailHeadline(plan);
    final progress = planProgress(plan);
    // One rule, one place. The two answers about the past make sense only while
    // there is nothing to measure from AND nobody has answered yet: once a
    // service is recorded the record IS the answer, and once somebody has said
    // "não sei" asking again is the nagging this change exists to remove.
    final canAnswerHistory =
        onHistoryUnknown != null &&
        noBaseline &&
        plan.historyStatus == MaintenanceHistoryStatus.notAsked;

    final lastValue = switch (plan) {
      _ when last != null => last,
      _ when plan.countsFromNew =>
        'Nunca foi feito — contamos a partir de quando o carro era novo',
      _ when plan.historyStatus == MaintenanceHistoryStatus.unknown =>
        'Você não lembra quando foi',
      _ => 'Sem data',
    };

    return ListView(
      padding: AppSpacing.screen,
      children: [
        // The state, as one surface: the glyph, the chip, the sentence, and
        // the bar when the figures allow one.
        AppSurface(
          variant: AppSurfaceVariant.grouped,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppIconWell(
                    icon: maintenanceIconFor(plan.itemSlug),
                    size: AppIconWellSize.l,
                    tone: status.isLoud
                        ? AppIconWellTone.status
                        : AppIconWellTone.neutral,
                    status: status,
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppStatusChip(status: status),
                        ),
                        if (headline.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            headline,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: status.isLoud
                                  ? visual.foreground
                                  : scheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: AppSpacing.s16),
                AppProgressBar(
                  value: progress,
                  color: status.isLoud ? visual.foreground : null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: appGroupGap),
        // The facts are one object — this item on this car — so they share one
        // surface, the same grouped list the rest of the app uses.
        AppGroup(
          dividerIndent: 0,
          footnote: howItWorks,
          children: [
            AppFactRow(label: 'Última vez', value: lastValue),
            if (next != null) AppFactRow(label: 'Próxima', value: next),
            if (interval != null)
              AppFactRow(
                label: 'Intervalo',
                value: interval,
                onTap: onAdjustInterval,
              ),
          ],
        ),
        if (plan.notes != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(
              plan.notes!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: appGroupGap),
        if (noBaseline) ...[
          // Without a date the item cannot come due, so the question the screen
          // asks first is when it was last done — with the two honest ways of
          // not knowing right under it.
          Text('Quando foi a última vez?', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Com a data e a quilometragem, o Meu Auto calcula a próxima e '
            'avisa na hora certa.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          AppButton(
            label: 'Informar a última vez',
            onPressed: onRegister,
            expanded: true,
          ),
          if (canAnswerHistory) ...[
            const SizedBox(height: AppSpacing.s8),
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
        ] else ...[
          AppButton(
            label: 'Registrar serviço',
            onPressed: onRegister,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.s8),
          AppButton(
            label: 'Ajustar intervalo',
            variant: AppButtonVariant.secondary,
            onPressed: onAdjustInterval,
            expanded: true,
          ),
        ],
        const SizedBox(height: appGroupGap),
        if (historyLoading) ...[
          const AppSectionHeader(title: 'Histórico deste item'),
          const AppSkeleton(width: double.infinity, height: 72),
        ] else if (history.isEmpty)
          const AppGroup(
            title: 'Histórico deste item',
            footnote:
                'Ainda não há serviço deste item. O primeiro registro começa o '
                'histórico.',
            children: [],
          )
        else
          AppGroup(
            title: 'Histórico deste item',
            dividerIndent: 0,
            children: [
              for (var i = 0; i < history.length; i++)
                _HistoryTile(
                  record: history[i],
                  previous: i + 1 < history.length ? history[i + 1] : null,
                  onTap: onOpenRecord == null
                      ? null
                      : () => onOpenRecord!(history[i]),
                ),
            ],
          ),
        if (plan.origin == MaintenancePlanOrigin.suggested) ...[
          const SizedBox(height: AppSpacing.s16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(
              'O intervalo sugerido é uma referência de mercado, não a '
              'recomendação do fabricante do seu carro. Se o manual disser '
              'outra coisa, ajuste o intervalo e os avisos passam a seguir o '
              'seu.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, this.previous, this.onTap});

  final MaintenanceRecord record;
  final MaintenanceRecord? previous;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previousRecord = previous;
    final km = record.mileageKm;
    final previousKm = previousRecord?.mileageKm;
    final delta = km == null || previousKm == null
        ? null
        : mileageSincePreviousPhrase(km, previousKm);
    final title = km == null
        ? formatCivilDateLong(record.occurredOn)
        : '${formatCivilDateLong(record.occurredOn)} · ${formatKm(km)}';

    return AppListRowShell(
      onTap: onTap,
      semanticLabel: delta == null ? title : '$title. $delta',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (delta != null)
                  Text(
                    delta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.outline,
            ),
        ],
      ),
    );
  }
}
